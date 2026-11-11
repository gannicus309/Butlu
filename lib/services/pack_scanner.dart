import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

import '../features/grocery/models/catalog.dart';
import '../features/inventory/models/expiry_parser.dart';
import '../features/inventory/models/inventory_item.dart';
import 'expiry_scanner.dart';

/// What one photo of a pack says: the product, and its date if one could
/// be read.
class PackScan {
  const PackScan({
    required this.item,
    required this.dateRead,
    required this.byGemini,
  });

  /// Ready to add: name, emoji, place and date filled in. When no date
  /// could be read, [InventoryItem.expiresAt] is the usual shelf life.
  final InventoryItem item;

  /// Whether the date came off the pack rather than being estimated.
  final bool dateRead;

  /// Read by Gemini, or by the phone alone (no key, offline, or Gemini
  /// failed).
  final bool byGemini;
}

sealed class PackScanResult {}

class PackFound extends PackScanResult {
  PackFound(this.scan);
  final PackScan scan;
}

/// Nothing recognisable in the photo.
class PackUnknown extends PackScanResult {
  PackUnknown(this.seen);

  /// The text that was read, to show why.
  final List<String> seen;
}

class PackFailed extends PackScanResult {
  PackFailed(this.message);
  final String message;
}

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
const _model = 'gemini-3.6-flash';

/// Takes a photo of a product and works out what it is and when it goes
/// off, so it can go straight into the inventory.
///
/// With a Gemini key the photo is sent to Gemini, which reads the label
/// and the printed date far better than text recognition alone -- it
/// knows "Frische Vollmilch 3,5%" is milk and which date is the
/// best-before. At the same time Apple Vision reads the text on the phone;
/// that's used for the date when Gemini can't find one, and for
/// everything when Gemini isn't available.
///
/// [onPhotoTaken] fires once there's a photo, so the caller can show
/// progress. Null if the user backed out of the camera.
Future<PackScanResult?> scanPack({
  bool fromLibrary = false,
  void Function()? onPhotoTaken,
}) async {
  try {
    final photo = await takePackPhoto(fromLibrary: fromLibrary, maxSide: 1600);
    if (photo == null) return null;
    onPhotoTaken?.call();

    final ocr = recognizeText(photo.path).catchError((_) => <String>[]);
    _GeminiRead? gemini;
    if (_apiKey.isNotEmpty) {
      try {
        gemini = await _askGemini(await photo.readAsBytes());
      } on Object {
        gemini = null; // Offline or refused: the phone's reading will do.
      }
    }
    final lines = await ocr;
    final now = DateTime.now();
    final ocrDate = parseExpiryDate(lines, now: now);

    if (gemini != null && gemini.product.isNotEmpty) {
      final catalog = kCatalogById[gemini.catalogId];
      final date = _sane(gemini.expiry, now) ?? ocrDate;
      return PackFound(
        PackScan(
          item: _item(
            name: catalog?.name ?? _title(gemini.product),
            catalog: catalog,
            storage: gemini.storage,
            spec: gemini.detail,
            expiresAt: date,
            now: now,
          ),
          dateRead: date != null,
          byGemini: true,
        ),
      );
    }

    final catalog = matchCatalog(lines);
    if (catalog == null && ocrDate == null) return PackUnknown(lines);
    return PackFound(
      PackScan(
        item: _item(
          name: catalog?.name ?? 'Scanned item',
          catalog: catalog,
          expiresAt: ocrDate,
          now: now,
        ),
        dateRead: ocrDate != null,
        byGemini: false,
      ),
    );
  } on ScanException catch (e) {
    return PackFailed(e.message);
  }
}

InventoryItem _item({
  required String name,
  required CatalogItem? catalog,
  required DateTime? expiresAt,
  required DateTime now,
  StorageLocation? storage,
  String spec = '',
}) => InventoryItem(
  id: '',
  name: name,
  emoji: catalog?.emoji ?? '🥫',
  category: catalog?.category ?? GroceryCategory.other,
  // The catalog knows best where its items live; Gemini's guess is for
  // things the catalog doesn't have.
  storage: catalog != null
      ? defaultStorage(catalog)
      : storage ?? defaultStorage(null),
  catalogId: catalog?.id,
  spec: spec,
  expiresAt: expiresAt ?? estimatedExpiry(catalog, from: now),
);

/// Ignores dates that can't be a best-before: well past, or years ahead.
DateTime? _sane(DateTime? d, DateTime now) {
  if (d == null) return null;
  if (d.isBefore(DateTime(now.year - 1, now.month, now.day))) return null;
  if (d.isAfter(DateTime(now.year + 10, now.month, now.day))) return null;
  return d;
}

String _title(String s) {
  final t = s.trim();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// The catalog item whose name (or German name) appears in text read off a
/// pack -- the longest such name, so "Vollmilch" beats "Milch" if both
/// exist. Null if none does.
CatalogItem? matchCatalog(List<String> lines) {
  final text = ' ${lines.join(' ').toLowerCase()} ';
  CatalogItem? best;
  var bestLength = 0;
  for (final item in kCatalog) {
    for (final term in [item.name, ...item.aliases]) {
      final t = term.toLowerCase();
      if (t.length <= bestLength) continue;
      // Short words only as whole words ("Ei" mustn't match "Weizen");
      // longer ones also inside compounds ("Milch" in "Vollmilch").
      final hit = t.length >= 4
          ? text.contains(t)
          : RegExp('(^|[^a-zäöüß])${RegExp.escape(t)}([^a-zäöüß]|\$)')
                .hasMatch(text);
      if (hit) {
        best = item;
        bestLength = t.length;
      }
    }
  }
  return best;
}

class _GeminiRead {
  _GeminiRead({
    required this.product,
    required this.catalogId,
    required this.expiry,
    required this.storage,
    required this.detail,
  });

  final String product;
  final String? catalogId;
  final DateTime? expiry;
  final StorageLocation? storage;
  final String detail;
}

Future<_GeminiRead?> _askGemini(Uint8List jpeg) async {
  final model = GenerativeModel(
    model: _model,
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      temperature: 0,
    ),
  );
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final catalog = [
    for (final c in kCatalog) '${c.id}: ${[c.name, ...c.aliases].join(' / ')}',
  ].join('\n');
  final prompt =
      '''
This is a photo of a grocery product someone is putting away at home in
Germany. Today is $today.

Identify the product and read its best-before / use-by date (MHD,
"mindestens haltbar bis", "zu verbrauchen bis", "best before", "use by").
Dates are printed day first (12.11.26 is 12 November 2026); a date with
only month and year means the last day of that month. Ignore packing,
production and batch dates. If several items are visible, describe the
main one. If you can't see a date, use null -- don't guess.

Answer with JSON only:
{"product": short everyday English name, e.g. "Milk", "Greek yogurt",
 "catalogId": the id from the list below that is the same kind of thing,
   or null if none fits,
 "expiry": "YYYY-MM-DD" or null,
 "storage": "fridge", "freezer", "pantry" or "household",
 "detail": brand and size in a few words, e.g. "Weihenstephan 1 L", or ""}

Catalog (id: names):
$catalog''';
  final response = await model
      .generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', jpeg)]),
      ])
      .timeout(const Duration(seconds: 25));
  final text = response.text;
  if (text == null) return null;
  final json = jsonDecode(text);
  if (json is! Map) return null;
  final expiry = json['expiry'];
  return _GeminiRead(
    product: '${json['product'] ?? ''}'.trim(),
    catalogId: json['catalogId'] is String ? json['catalogId'] as String : null,
    expiry: expiry is String ? DateTime.tryParse(expiry) : null,
    storage: StorageLocation.values.asNameMap()[json['storage']],
    detail: json['detail'] is String ? (json['detail'] as String).trim() : '',
  );
}
