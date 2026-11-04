import 'package:cloud_firestore/cloud_firestore.dart';

import '../crypto/vault_crypto.dart';
import '../models/vault_note.dart';

/// Shared-family notes vault, backed by `/families/{familyId}/vaultNotes`.
///
/// Titles and bodies are stored only sealed (see vault_crypto.dart): a
/// document holds `sealed` (ciphertext), `keyId`, `createdByUid` and
/// `updatedAt` -- nothing readable about what the note says.
class VaultRepository {
  VaultRepository({
    required this.familyId,
    required this.key,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final VaultKey key;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _firestore.collection('families').doc(familyId).collection('vaultNotes');

  Stream<List<VaultNote>> watchNotes() => _notes.snapshots().asyncMap(
    (snapshot) async => await Future.wait(snapshot.docs.map(_fromDoc))
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  Future<void> addNote({
    required String title,
    required String body,
    required String createdByUid,
  }) async {
    await _notes.add({
      ...await _sealedFields(title, body, clearPlain: false),
      'createdByUid': createdByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNote(
    String noteId, {
    required String title,
    required String body,
  }) async {
    await _notes.doc(noteId).update({
      ...await _sealedFields(title, body),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _notes.doc(noteId).delete();
  }

  /// Encrypts notes saved before Vault encryption existed, removing their
  /// readable title and body from Firestore. Safe to run repeatedly.
  Future<void> sealPlainNotes() async {
    final snapshot = await _notes.get();
    final batch = _firestore.batch();
    var any = false;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['sealed'] != null) continue;
      any = true;
      batch.update(
        doc.reference,
        await _sealedFields(
          data['title'] as String? ?? '',
          data['body'] as String? ?? '',
        ),
      );
    }
    if (any) await batch.commit();
  }

  /// The sealed fields to write. For an update, [clearPlain] also removes
  /// any old readable title/body (Firestore only allows that in updates).
  Future<Map<String, Object>> _sealedFields(
    String title,
    String body, {
    bool clearPlain = true,
  }) async {
    final sealed = await sealNote(key, title: title, body: body);
    return {
      'sealed': sealed.data,
      'keyId': sealed.keyId,
      if (clearPlain) ...{
        'title': FieldValue.delete(),
        'body': FieldValue.delete(),
      },
    };
  }

  Future<VaultNote> _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final updatedAt = data['updatedAt'];
    final base = (
      id: doc.id,
      createdByUid: data['createdByUid'] as String? ?? '',
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : DateTime.now(),
    );
    final sealed = data['sealed'] as String?;
    if (sealed == null) {
      // Not encrypted yet; sealPlainNotes() will take care of it.
      return VaultNote(
        id: base.id,
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        createdByUid: base.createdByUid,
        updatedAt: base.updatedAt,
      );
    }
    try {
      final opened = await openNote(
        key,
        SealedNote(keyId: data['keyId'] as String? ?? '', data: sealed),
      );
      return VaultNote(
        id: base.id,
        title: opened.title,
        body: opened.body,
        createdByUid: base.createdByUid,
        updatedAt: base.updatedAt,
      );
    } catch (_) {
      // Sealed with another key, or damaged: show that it exists without
      // pretending to know what's in it.
      return VaultNote(
        id: base.id,
        title: 'Locked note',
        body: '',
        createdByUid: base.createdByUid,
        updatedAt: base.updatedAt,
        unreadable: true,
      );
    }
  }
}
