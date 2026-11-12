import 'package:butlu/features/grocery/models/catalog.dart';
import 'package:butlu/features/inventory/models/inventory_item.dart';
import 'package:flutter_test/flutter_test.dart';

FoodGroup g(
  String name, {
  String? id,
  GroceryCategory c = GroceryCategory.other,
}) => foodGroupFor(
  catalogId: id,
  category: kCatalogById[id]?.category ?? c,
  storage: kCatalogById[id]?.storage ?? StorageLocation.fridge,
  name: name,
);

void main() {
  test('catalog items land in the right group', () {
    expect(g('Eggs', id: 'eggs'), FoodGroup.protein);
    expect(g('Chicken', id: 'chicken'), FoodGroup.protein);
    expect(g('Pasta', id: 'pasta'), FoodGroup.carbs);
    expect(g('Bread', id: 'bread'), FoodGroup.carbs);
    expect(g('Spinach', id: 'spinach'), FoodGroup.other);
    expect(g('Toothpaste', id: 'toothpaste'), FoodGroup.household);
    expect(g('Cleaner', id: 'cleaner'), FoodGroup.household);
  });
  test('scanned items are grouped by name', () {
    expect(g('Griechischer Joghurt'), FoodGroup.protein);
    expect(g('Basmati Reis'), FoodGroup.carbs);
    expect(g('Matcha Pulver'), FoodGroup.other);
  });
}
