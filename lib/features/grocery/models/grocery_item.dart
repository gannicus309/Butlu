/// A grocery item tracked from purchase to its expiry date.
class GroceryItem {
  final String id;
  final String name;
  final DateTime expiryDate;
  final String addedByUid;
  final DateTime createdAt;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.expiryDate,
    required this.addedByUid,
    required this.createdAt,
  });

  /// Days until [expiryDate], relative to local midnight today. Negative
  /// once the item has expired.
  int daysUntilExpiry() {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final expiryMidnight =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiryMidnight.difference(todayMidnight).inDays;
  }
}
