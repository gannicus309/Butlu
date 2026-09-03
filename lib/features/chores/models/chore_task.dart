/// A chore, either floating unclaimed (`assignedToUid == null`) or claimed
/// by whoever tapped its bubble.
class ChoreTask {
  final String id;
  final String title;
  final String? assignedToUid;
  final String createdByUid;
  final DateTime createdAt;
  final bool done;

  const ChoreTask({
    required this.id,
    required this.title,
    required this.assignedToUid,
    required this.createdByUid,
    required this.createdAt,
    required this.done,
  });
}
