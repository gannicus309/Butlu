/// A bill or subscription tracked from due date to (manually marked) paid.
class Bill {
  final String id;
  final String name;
  final double? amount;
  final DateTime dueDate;
  final bool autoPay;
  final String createdByUid;

  const Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.autoPay,
    required this.createdByUid,
  });

  int daysUntilDue() {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dueMidnight = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueMidnight.difference(todayMidnight).inDays;
  }
}
