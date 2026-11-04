import 'catalog.dart';

/// Something on the family's shopping list. Keyed by its catalog id (or
/// [customItemId] for typed-in items), so the same thing can only be on the
/// list once, whoever adds it.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    this.spec = '',
    this.addedByUid,
    this.addedAt,
  });

  factory ShoppingItem.fromCatalog(CatalogItem item, {String spec = ''}) =>
      ShoppingItem(
        id: item.id,
        name: item.name,
        emoji: item.emoji,
        category: item.category,
        spec: spec,
      );

  factory ShoppingItem.custom(String name) => ShoppingItem(
    id: customItemId(name),
    name: name.trim(),
    emoji: '🛒',
    category: GroceryCategory.other,
  );

  final String id;
  final String name;
  final String emoji;
  final GroceryCategory category;

  /// Free-text detail shown under the name, like Bring's: "2 L", "organic".
  final String spec;
  final String? addedByUid;
  final DateTime? addedAt;

  /// The catalog entry this came from, if any -- carries storage place and
  /// shelf life for when it's bought and moves into the pantry inventory.
  CatalogItem? get catalogItem => kCatalogById[id];

  ShoppingItem copyWith({String? spec}) => ShoppingItem(
    id: id,
    name: name,
    emoji: emoji,
    category: category,
    spec: spec ?? this.spec,
    addedByUid: addedByUid,
    addedAt: addedAt,
  );
}

/// What the family has bought or listed before, for "Recently used" -- and
/// later, for the inventory's "put away what you just bought".
class GroceryHistoryEntry {
  const GroceryHistoryEntry({
    required this.item,
    required this.lastUsedAt,
    this.lastBoughtAt,
    this.putAwayAt,
    this.timesBought = 0,
  });

  final ShoppingItem item;
  final DateTime lastUsedAt;
  final DateTime? lastBoughtAt;

  /// When it was last put into (or skipped for) the pantry inventory.
  final DateTime? putAwayAt;
  final int timesBought;

  /// Bought in the last week and not put away since -- what the inventory's
  /// "Put away" prompt offers.
  bool awaitingPutAway(DateTime now) {
    final bought = lastBoughtAt;
    if (bought == null) return false;
    if (now.difference(bought) > const Duration(days: 7)) return false;
    final putAway = putAwayAt;
    return putAway == null || putAway.isBefore(bought);
  }
}
