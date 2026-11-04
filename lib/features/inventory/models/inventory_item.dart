import '../../grocery/models/catalog.dart';

/// Something in the fridge, freezer or pantry, with when it goes off.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.storage,
    this.catalogId,
    this.spec = '',
    this.expiresAt,
    this.addedAt,
  });

  final String id;
  final String name;
  final String emoji;
  final GroceryCategory category;
  final StorageLocation storage;

  /// Catalog entry it came from, if any -- what Gemini meal planning and
  /// "add to shopping list" match on.
  final String? catalogId;

  /// Free-text detail, e.g. "half a pack", "2 L".
  final String spec;

  /// Use-by / best-before as a local date. Null for things that don't go
  /// off, or that nobody dated.
  final DateTime? expiresAt;
  final DateTime? addedAt;

  /// Whole days until [expiresAt] from today; negative once past it.
  int? daysLeft([DateTime? now]) {
    final e = expiresAt;
    if (e == null) return null;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return DateTime(e.year, e.month, e.day).difference(today).inDays;
  }

  InventoryItem copyWith({
    StorageLocation? storage,
    DateTime? expiresAt,
    bool clearExpiry = false,
    String? spec,
  }) => InventoryItem(
    id: id,
    name: name,
    emoji: emoji,
    category: category,
    storage: storage ?? this.storage,
    catalogId: catalogId,
    spec: spec ?? this.spec,
    expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
    addedAt: addedAt,
  );
}

/// A suggested use-by date for something just bought: today plus the
/// catalog's rough shelf life, or a week for unknown items. Null for things
/// that don't go off (household, personal care).
DateTime? estimatedExpiry(
  CatalogItem? item, {
  required DateTime from,
  int unknownDays = 7,
}) {
  final days = item == null ? unknownDays : item.shelfLifeDays;
  if (days == null) return null;
  final day = DateTime(from.year, from.month, from.day);
  return day.add(Duration(days: days));
}

/// Where a just-bought item goes by default: the catalog's place, or the
/// fridge for unknown items (the safe guess for anything perishable).
StorageLocation defaultStorage(CatalogItem? item) =>
    item?.storage ?? StorageLocation.fridge;

extension StorageLabel on StorageLocation {
  String get label => switch (this) {
    StorageLocation.fridge => 'Fridge',
    StorageLocation.freezer => 'Freezer',
    StorageLocation.pantry => 'Pantry',
    StorageLocation.household => 'Cupboard',
  };

  String get emoji => switch (this) {
    StorageLocation.fridge => '🧊',
    StorageLocation.freezer => '❄️',
    StorageLocation.pantry => '🥫',
    StorageLocation.household => '🧴',
  };
}
