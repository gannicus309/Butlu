import 'package:butlu/features/grocery/models/catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog ids are unique', () {
    final ids = kCatalog.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every category has items', () {
    for (final c in GroceryCategory.values.where(
      (c) => c != GroceryCategory.other,
    )) {
      expect(kCatalog.any((i) => i.category == c), isTrue, reason: c.name);
    }
  });

  test('search finds by name first, then by German alias', () {
    expect(searchCatalog('milk').first.id, 'milk');
    expect(searchCatalog('Milch').first.id, 'milk');
  });

  test('umlauts match plain letters', () {
    expect(searchCatalog('apfel').first.id, 'apples');
    expect(searchCatalog('Äpfel').first.id, 'apples');
    expect(searchCatalog('kase').map((i) => i.id), contains('cheese'));
  });

  test('custom items get a stable id', () {
    expect(customItemId('Dosa batter'), 'custom-dosa-batter');
    expect(customItemId('  Dosa  Batter! '), 'custom-dosa-batter');
  });
}
