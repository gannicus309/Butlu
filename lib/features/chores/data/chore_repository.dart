import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chore_task.dart';

/// Shared-family chore list, backed by `/families/{familyId}/choreTasks`.
class ChoreRepository {
  ChoreRepository({required this.familyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _firestore.collection('families').doc(familyId).collection('choreTasks');

  Stream<List<ChoreTask>> watchTasks() {
    return _tasks.where('done', isEqualTo: false).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// Adds a chore. Omit [assignedToUid] to add it as an unclaimed floating
  /// bubble; pass it to add and immediately claim in one step (used for
  /// tapping a suggestion chip).
  Future<void> addTask({
    required String title,
    required String createdByUid,
    String? assignedToUid,
  }) async {
    await _tasks.add({
      'title': title,
      'assignedToUid': assignedToUid,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'done': false,
    });
  }

  Future<void> claimTask(String taskId, String uid) async {
    await _tasks.doc(taskId).update({'assignedToUid': uid});
  }

  Future<void> markDone(String taskId) async {
    await _tasks.doc(taskId).update({'done': true});
  }

  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }

  ChoreTask _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return ChoreTask(
      id: doc.id,
      title: data['title'] as String,
      assignedToUid: data['assignedToUid'] as String?,
      createdByUid: data['createdByUid'] as String,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      done: data['done'] as bool? ?? false,
    );
  }
}
