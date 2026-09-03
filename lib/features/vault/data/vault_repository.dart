import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vault_note.dart';

/// Shared-family notes vault, backed by `/families/{familyId}/vaultNotes`.
class VaultRepository {
  VaultRepository({required this.familyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notes =>
      _firestore.collection('families').doc(familyId).collection('vaultNotes');

  Stream<List<VaultNote>> watchNotes() {
    return _notes.snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
        );
  }

  Future<void> addNote({
    required String title,
    required String body,
    required String createdByUid,
  }) async {
    await _notes.add({
      'title': title,
      'body': body,
      'createdByUid': createdByUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNote(String noteId, {String? title, String? body}) async {
    await _notes.doc(noteId).update({
      'title': ?title,
      'body': ?body,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _notes.doc(noteId).delete();
  }

  VaultNote _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final updatedAt = data['updatedAt'];
    return VaultNote(
      id: doc.id,
      title: data['title'] as String,
      body: data['body'] as String? ?? '',
      createdByUid: data['createdByUid'] as String,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : DateTime.now(),
    );
  }
}
