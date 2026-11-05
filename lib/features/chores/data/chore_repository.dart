import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chore.dart';
import '../models/chore_load.dart';

/// The family's to-dos (`/families/{id}/chores`) and the log of completed
/// ones (`/choreLog`) that the load charts are drawn from.
class ChoreRepository {
  ChoreRepository({required this.familyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _family =>
      _firestore.collection('families').doc(familyId);

  CollectionReference<Map<String, dynamic>> get _chores =>
      _family.collection('chores');

  CollectionReference<Map<String, dynamic>> get _log =>
      _family.collection('choreLog');

  Stream<List<Chore>> watchChores() =>
      _chores.snapshots().map((s) => [for (final d in s.docs) _chore(d)]);

  /// Completions from the last ~6 months -- as far back as the charts go.
  Stream<List<ChoreCompletion>> watchLog(DateTime now) => _log
      .where(
        'completedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(now.year, now.month - 6),
        ),
      )
      .snapshots()
      .map((s) => [for (final d in s.docs) _completion(d.data())]);

  Future<void> save(Chore chore, {required String uid}) async {
    final fields = _fields(chore);
    if (chore.id.isEmpty) {
      await _chores.add({
        ...fields,
        'createdByUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _chores.doc(chore.id).update(fields);
    }
  }

  Future<void> delete(String id) => _chores.doc(id).delete();

  /// Ticks a task off: logs the completion, then either removes a one-off or
  /// moves a repeating task to its next date. Returns what [undoComplete]
  /// needs to put things back.
  /// [doneBy] is who ticked it off; the load charts credit the task's
  /// assignee, or [doneBy] when it was for anyone.
  Future<({Chore before, String logId})> complete(
    Chore chore, {
    required DateTime now,
    required String doneBy,
  }) async {
    final log = _log.doc();
    final batch = _firestore.batch()
      ..set(log, {
        'choreId': chore.id,
        'title': chore.title,
        'kind': chore.kind.name,
        'subtype': chore.subtype.name,
        'assignee': chore.assignee ?? doneBy,
        'doneBy': doneBy,
        'completedAt': Timestamp.fromDate(now),
      });
    if (chore.repeat == ChoreRepeat.none) {
      batch.delete(_chores.doc(chore.id));
    } else {
      batch.update(_chores.doc(chore.id), {
        'dueAt': Timestamp.fromDate(nextDue(chore, now)),
      });
    }
    await batch.commit();
    return (before: chore, logId: log.id);
  }

  Future<void> undoComplete(({Chore before, String logId}) done) async {
    final batch = _firestore.batch()
      ..delete(_log.doc(done.logId))
      ..set(_chores.doc(done.before.id), {
        ..._fields(done.before),
        'createdAt': done.before.createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(done.before.createdAt!),
      }, SetOptions(merge: true));
    await batch.commit();
  }

  /// One-time move of the old Chores tab's tasks (`/choreTasks`) into the
  /// new list as one-off tasks. Safe to call repeatedly.
  Future<void> importOldTasks() async {
    final old = await _family.collection('choreTasks').get();
    if (old.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in old.docs) {
      final data = doc.data();
      if (data['done'] != true) {
        batch.set(_chores.doc(), {
          ..._fields(Chore(id: '', title: data['title'] as String? ?? 'Task')),
          'createdByUid': data['createdByUid'],
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        });
      }
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Map<String, Object?> _fields(Chore c) => {
    'title': c.title,
    'details': c.details,
    'dueAt': c.dueAt == null ? null : Timestamp.fromDate(c.dueAt!),
    'hasTime': c.hasTime,
    'subtype': c.subtype.name,
    'tags': c.tags,
    'repeat': c.repeat.name,
    'priority': c.priority,
    'assignee': c.assignee,
  };

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  static Chore _chore(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return Chore(
      id: d.id,
      title: data['title'] as String? ?? '',
      details: data['details'] as String? ?? '',
      dueAt: _date(data['dueAt']),
      hasTime: data['hasTime'] as bool? ?? false,
      subtype:
          ChoreSubtype.values.asNameMap()[data['subtype']] ??
          ChoreSubtype.house,
      tags: [for (final t in data['tags'] as List? ?? const []) '$t'],
      repeat:
          ChoreRepeat.values.asNameMap()[data['repeat']] ?? ChoreRepeat.none,
      priority: data['priority'] as bool? ?? false,
      assignee: data['assignee'] as String?,
      createdAt: _date(data['createdAt']),
    );
  }

  static ChoreCompletion _completion(Map<String, dynamic> data) =>
      ChoreCompletion(
        choreId: data['choreId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        kind: ChoreKind.values.asNameMap()[data['kind']] ?? ChoreKind.special,
        subtype:
            ChoreSubtype.values.asNameMap()[data['subtype']] ??
            ChoreSubtype.house,
        assignee: data['assignee'] as String? ?? 'Anyone',
        completedAt: _date(data['completedAt']) ?? DateTime.now(),
      );
}
