import 'dart:convert';
import 'dart:io';

/// A product as Open Food Facts (openfoodfacts.org, a free, open database
/// of ~4 million packaged foods) knows it by its barcode.
class FoodFacts {
  const FoodFacts({
    required this.barcode,
    required this.name,
    required this.genericName,
    required this.brand,
    required this.quantity,
    required this.categories,
  });

  final String barcode;

  /// As on the pack, e.g. "Frische Vollmilch 3,5%".
  final String name;

  /// What kind of thing it is, e.g. "Hazelnut and cocoa spread"; often
  /// empty.
  final String genericName;

  /// First brand listed, e.g. "Weihenstephan".
  final String brand;

  /// e.g. "1 l", "400 g".
  final String quantity;

  /// Readable category words, most general first: "dairies", "milks",
  /// "whole milks", ...
  final List<String> categories;

  /// Brand, product and size in a few words, for an item's details.
  String get detail {
    final parts = <String>[
      if (brand.isNotEmpty && !name.toLowerCase().contains(brand.toLowerCase()))
        brand,
      if (name.isNotEmpty) name,
      if (quantity.isNotEmpty) quantity,
    ];
    return parts.join(' · ');
  }
}

/// Looks [barcode] up in Open Food Facts. Null if it isn't there, or the
/// lookup failed (offline, slow) -- the photo is still read without it.
/// Only the barcode digits are sent.
Future<FoodFacts?> lookUpBarcode(String barcode) async {
  if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(
      Uri.https('world.openfoodfacts.org', '/api/v2/product/$barcode.json', {
        'fields':
            'product_name,product_name_de,product_name_en,generic_name,'
            'generic_name_en,brands,quantity,categories_tags',
      }),
    );
    // Open Food Facts asks apps to say who they are.
    request.headers.set(HttpHeaders.userAgentHeader, 'Butlu/1.2 (iOS)');
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 6));
    final json = jsonDecode(body);
    if (json is! Map || json['status'] != 1) return null;
    final p = json['product'];
    if (p is! Map) return null;
    String str(String key) => p[key] is String ? (p[key] as String).trim() : '';
    final name = [
      str('product_name_de'),
      str('product_name'),
      str('product_name_en'),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final generic = [
      str('generic_name_en'),
      str('generic_name'),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (name.isEmpty && generic.isEmpty) return null;
    return FoodFacts(
      barcode: barcode,
      name: name,
      genericName: generic,
      brand: str('brands').split(',').first.trim(),
      quantity: str('quantity'),
      categories: [
        for (final t in p['categories_tags'] as List? ?? const [])
          if (t is String && t.startsWith('en:'))
            t.substring(3).replaceAll('-', ' '),
      ],
    );
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}
