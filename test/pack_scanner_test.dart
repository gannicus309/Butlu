import 'package:butlu/services/pack_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds the product in text read off a pack', () {
    expect(
      matchCatalog(['Weihenstephan', 'Frische Vollmilch', '3,5% Fett'])?.id,
      'milk',
    );
    expect(matchCatalog(['MHD 20.11.26', 'L4711']), isNull);
    // As Open Food Facts describes a barcode's product.
    expect(
      matchCatalog(['', 'Frische Vollmilch 3,5%', 'dairies', 'milks']),
      isNotNull,
    );
  });
}
