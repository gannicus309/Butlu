import 'package:cloud_firestore/cloud_firestore.dart';

/// Family document CRUD + the invite/join flow. See firestore.rules for the
/// authorization model this mirrors exactly -- `createFamily` and `join`
/// must produce writes shaped the way the security rules expect, or they'll
/// be rejected server-side.
class FamilyService {
  FamilyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _families =>
      _firestore.collection('families');

  /// One record per invited email (`/invites/{email}`), readable only by
  /// that email's account. A direct read, unlike searching all families
  /// for one listing the email, which security rules refuse for someone
  /// who isn't a member yet.
  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('invites');

  static String _norm(String email) => email.trim().toLowerCase();

  /// The family this uid is already a member of, if any.
  Future<String?> findFamilyIdForMember(String uid) async {
    final snapshot = await _families
        .where('memberUids', arrayContains: uid)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.id;
  }

  /// A family this email has been invited to but hasn't joined yet.
  Future<({String familyId, String name})?> findPendingInvite(
    String email,
  ) async {
    final invite = await _invites.doc(_norm(email)).get();
    final data = invite.data();
    if (data == null) return null;
    return (
      familyId: data['familyId'] as String,
      name: data['familyName'] as String? ?? 'your family',
    );
  }

  /// Makes sure every email on the family's invite list has its invite
  /// record -- for invites made before those records existed. Run by a
  /// member's phone.
  Future<void> syncInvites(String familyId) async {
    final family = await _families.doc(familyId).get();
    final data = family.data();
    if (data == null) return;
    final batch = _firestore.batch();
    for (final e in data['invitedEmails'] as List? ?? const []) {
      batch.set(_invites.doc(_norm('$e')), {
        'familyId': familyId,
        'familyName': data['name'],
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<String> createFamily({
    required String creatorUid,
    required String creatorDisplayName,
    required String creatorEmail,
    required String spouseEmail,
    String? familyName,
  }) async {
    final doc = _families.doc();
    await doc.set({
      'name': familyName ?? "$creatorDisplayName's family",
      'memberUids': [creatorUid],
      'invitedEmails': [_norm(creatorEmail), _norm(spouseEmail)],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await doc.collection('members').doc(creatorUid).set({
      'displayName': creatorDisplayName,
      'email': creatorEmail,
      'outlookAccountConnected': false,
    });
    await syncInvites(doc.id);
    return doc.id;
  }

  /// A family of one for an anonymous development account (`kDevSignIn`).
  /// There's no email to invite with, so `invitedEmails` is empty; the
  /// matching firestore.rules case only allows this for anonymous accounts.
  Future<String> createDevFamily(String uid) async {
    final doc = _families.doc();
    await doc.set({
      'name': 'Dev family',
      'memberUids': [uid],
      'invitedEmails': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await doc.collection('members').doc(uid).set({
      'displayName': 'Developer',
      'email': null,
      'outlookAccountConnected': false,
    });
    return doc.id;
  }

  /// Lets someone else join an existing family: they see it the next time
  /// they sign in with this Google account.
  Future<void> invite(String familyId, String email) async {
    await _families.doc(familyId).update({
      'invitedEmails': FieldValue.arrayUnion([_norm(email)]),
    });
    await syncInvites(familyId);
  }

  Future<void> joinFamily({
    required String familyId,
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final doc = _families.doc(familyId);
    // Each step says what failed, so a refusal can be traced to its rule.
    try {
      await doc.update({
        'memberUids': FieldValue.arrayUnion([uid]),
      });
    } on FirebaseException catch (e) {
      throw StateError('Joining the family failed: ${e.message}');
    }
    try {
      await doc.collection('members').doc(uid).set({
        'displayName': displayName,
        'email': email,
        'outlookAccountConnected': false,
      });
    } on FirebaseException catch (e) {
      throw StateError('Saving your profile failed: ${e.message}');
    }
    // Done with the invite; a leftover one is harmless.
    try {
      await _invites.doc(_norm(email)).delete();
    } on FirebaseException {
      // Ignore.
    }
  }
}
