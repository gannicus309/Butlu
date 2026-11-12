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
    this.groupOverride,
    this.low = false,
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

  /// Set when someone moved it to another group by hand; otherwise the
  /// group is worked out from what it is ([group]).
  final FoodGroup? groupOverride;

  /// Household supplies: marked as running low (and put on the list).
  final bool low;

  FoodGroup get group =>
      groupOverride ??
      foodGroupFor(
        catalogId: catalogId,
        category: category,
        storage: storage,
        name: name,
      );

  /// Whole days until [expiresAt] from today; negative once past it.
  int? daysLeft([DateTime? now]) {
    final e = expiresAt;
    if (e == null) return null;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return DateTime(e.year, e.month, e.day).difference(today).inDays;
  }

  InventoryItem copyWith({
    FoodGroup? group,
    bool? low,
    String? name,
    StorageLocation? storage,
    DateTime? expiresAt,
    bool clearExpiry = false,
    String? spec,
    String? id,
  }) => InventoryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji,
    category: category,
    storage: storage ?? this.storage,
    catalogId: catalogId,
    spec: spec ?? this.spec,
    expiresAt: clearExpiry ? null : (expiresAt ?? this.expiresAt),
    addedAt: addedAt,
    groupOverride: group ?? groupOverride,
    low: low ?? this.low,
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

/// How the inventory is split up: what it's for, not where it's kept.
enum FoodGroup {
  protein('Protein', '🥩'),
  carbs('Carbs', '🍞'),
  other('Other food', '🥦'),

  /// Cleaning things, toiletries and other supplies: no use-by date, just
  /// "have it" or "running low".
  household('Household', '🧴');

  const FoodGroup(this.label, this.emoji);
  final String label;
  final String emoji;
}

const _protein = {
  'eggs',
  'cheese',
  'sliced-cheese',
  'mozzarella',
  'feta',
  'paneer',
  'yogurt',
  'quark',
  'milk',
  'lentils',
  'chickpeas',
  'beans',
  'nuts',
  'peanut-butter',
  'fish-fingers',
  'tofu',
};
const _carbs = {
  'rice',
  'pasta',
  'noodles',
  'flour',
  'oats',
  'cereal',
  'potatoes',
  'sweet-potatoes',
  'fries',
  'pizza',
  'corn',
  'sugar',
};
const _proteinWords = [
  'chicken',
  'hähnchen',
  'huhn',
  'beef',
  'rind',
  'pork',
  'schwein',
  'lamb',
  'fish',
  'fisch',
  'lachs',
  'salmon',
  'tuna',
  'thunfisch',
  'egg',
  'eier',
  'tofu',
  'tempeh',
  'paneer',
  'cheese',
  'käse',
  'quark',
  'yogurt',
  'joghurt',
  'skyr',
  'lentil',
  'linsen',
  'dal',
  'chickpea',
  'kichererbsen',
  'bean',
  'bohnen',
  'prawn',
  'garnelen',
  'mince',
  'hack',
  'sausage',
  'wurst',
  'ham',
  'schinken',
  'protein',
  'whey',
  'milk',
  'milch',
];
const _carbWords = [
  'bread',
  'brot',
  'toast',
  'roll',
  'brötchen',
  'rice',
  'reis',
  'pasta',
  'nudel',
  'spaghetti',
  'noodle',
  'flour',
  'mehl',
  'oat',
  'hafer',
  'cereal',
  'müsli',
  'muesli',
  'potato',
  'kartoffel',
  'couscous',
  'quinoa',
  'bulgur',
  'wrap',
  'tortilla',
  'naan',
  'bagel',
  'croissant',
  'pizza',
  'fries',
  'pommes',
  'gnocchi',
  'semolina',
  'grieß',
  'atta',
  'poha',
  'idli',
  'dosa',
];

/// The group an item belongs in, from its catalog entry when it has one,
/// otherwise from its name.
FoodGroup foodGroupFor({
  required String? catalogId,
  required GroceryCategory category,
  required StorageLocation storage,
  required String name,
}) {
  if (category == GroceryCategory.household ||
      category == GroceryCategory.personal ||
      storage == StorageLocation.household) {
    return FoodGroup.household;
  }
  if (catalogId != null) {
    if (_protein.contains(catalogId)) return FoodGroup.protein;
    if (_carbs.contains(catalogId)) return FoodGroup.carbs;
    if (category == GroceryCategory.meatFish) return FoodGroup.protein;
    if (category == GroceryCategory.bakery) return FoodGroup.carbs;
    return FoodGroup.other;
  }
  if (category == GroceryCategory.meatFish) return FoodGroup.protein;
  if (category == GroceryCategory.bakery) return FoodGroup.carbs;
  final n = name.toLowerCase();
  if (_proteinWords.any(n.contains)) return FoodGroup.protein;
  if (_carbWords.any(n.contains)) return FoodGroup.carbs;
  return FoodGroup.other;
}
