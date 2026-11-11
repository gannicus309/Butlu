import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member_status.dart';

/// Lightweight "where are you" status board, one doc per member, backed by
/// `/families/{familyId}/status`.
class StatusRepository {
  StatusRepository({required this.familyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _statuses =>
      _firestore.collection('families').doc(familyId).collection('status');

  Stream<List<MemberStatus>> watchStatuses() {
    return _statuses.snapshots().map(
      (snapshot) => snapshot.docs.map(_fromDoc).toList(),
    );
  }

  Future<void> setStatus(String uid, String label) async {
    await _statuses.doc(uid).set({
      'label': label,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  MemberStatus _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final updatedAt = data['updatedAt'];
    return MemberStatus(
      uid: doc.id,
      label: data['label'] as String,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : DateTime.now(),
    );
  }
}
