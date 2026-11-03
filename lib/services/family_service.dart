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

  /// The family this uid is already a member of, if any.
  Future<String?> findFamilyIdForMember(String uid) async {
    final snapshot =
        await _families.where('memberUids', arrayContains: uid).limit(1).get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first.id;
  }

  /// A family this email has been invited to but hasn't joined yet.
  Future<({String familyId, String name})?> findPendingInvite(
    String email,
  ) async {
    final snapshot = await _families
        .where('invitedEmails', arrayContains: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return (familyId: doc.id, name: doc.data()['name'] as String);
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
      'invitedEmails': [creatorEmail, spouseEmail],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await doc.collection('members').doc(creatorUid).set({
      'displayName': creatorDisplayName,
      'email': creatorEmail,
      'outlookAccountConnected': false,
    });
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

  Future<void> joinFamily({
    required String familyId,
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final doc = _families.doc(familyId);
    await doc.update({
      'memberUids': FieldValue.arrayUnion([uid]),
    });
    await doc.collection('members').doc(uid).set({
      'displayName': displayName,
      'email': email,
      'outlookAccountConnected': false,
    });
  }
}
