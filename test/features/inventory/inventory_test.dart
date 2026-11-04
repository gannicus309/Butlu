import 'package:butlu/features/grocery/models/catalog.dart';
import 'package:butlu/features/grocery/models/shopping_item.dart';
import 'package:butlu/features/inventory/models/inventory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bought = DateTime(2026, 11, 4, 18, 30);

  test('use-by is estimated from the catalog shelf life', () {
    expect(
      estimatedExpiry(kCatalogById['milk'], from: bought),
      DateTime(2026, 11, 11),
    );
  });

  test('household items get no date, unknown items a week', () {
    expect(estimatedExpiry(kCatalogById['toilet-paper'], from: bought), isNull);
    expect(estimatedExpiry(null, from: bought), DateTime(2026, 11, 11));
  });

  test('items go where the catalog says, unknown ones in the fridge', () {
    expect(defaultStorage(kCatalogById['ice-cream']), StorageLocation.freezer);
    expect(defaultStorage(null), StorageLocation.fridge);
  });

  test('days left counts whole days from today', () {
    final item = InventoryItem(
      id: 'x',
      name: 'Milk',
      emoji: '🥛',
      category: GroceryCategory.dairy,
      storage: StorageLocation.fridge,
      expiresAt: DateTime(2026, 11, 6),
    );
    expect(item.daysLeft(DateTime(2026, 11, 4, 23, 59)), 2);
    expect(item.daysLeft(DateTime(2026, 11, 7, 8)), -1);
  });

  group('waiting to be put away', () {
    GroceryHistoryEntry entry({DateTime? boughtAt, DateTime? putAwayAt}) =>
        GroceryHistoryEntry(
          item: ShoppingItem.fromCatalog(kCatalogById['milk']!),
          lastUsedAt: bought,
          lastBoughtAt: boughtAt,
          putAwayAt: putAwayAt,
        );
    final now = DateTime(2026, 11, 5);

    test('just bought and not put away: yes', () {
      expect(entry(boughtAt: bought).awaitingPutAway(now), isTrue);
    });

    test('put away after buying: no', () {
      final e = entry(
        boughtAt: bought,
        putAwayAt: bought.add(const Duration(hours: 1)),
      );
      expect(e.awaitingPutAway(now), isFalse);
    });

    test('bought again after the last put-away: yes', () {
      final e = entry(
        boughtAt: bought,
        putAwayAt: bought.subtract(const Duration(days: 3)),
      );
      expect(e.awaitingPutAway(now), isTrue);
    });

    test('bought over a week ago, or never: no', () {
      expect(
        entry(boughtAt: bought)
            .awaitingPutAway(bought.add(const Duration(days: 8))),
        isFalse,
      );
      expect(entry().awaitingPutAway(now), isFalse);
    });
  });
}
