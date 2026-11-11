import 'package:cloud_firestore/cloud_firestore.dart';

import '../../grocery/models/catalog.dart';
import '../models/inventory_item.dart';

/// The family's fridge/freezer/pantry, under `/families/{id}/inventory`,
/// shared live between family members.
class InventoryRepository {
  InventoryRepository({required this.familyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _family =>
      _firestore.collection('families').doc(familyId);

  CollectionReference<Map<String, dynamic>> get _items =>
      _family.collection('inventory');

  Stream<List<InventoryItem>> watch() =>
      _items.snapshots().map((s) => [for (final d in s.docs) _from(d)]);

  Future<void> addAll(List<InventoryItem> items, {required String uid}) async {
    if (items.isEmpty) return;
    final batch = _firestore.batch();
    for (final item in items) {
      batch.set(_items.doc(), {..._fields(item), 'addedByUid': uid});
    }
    await batch.commit();
  }

  /// Adds one item and returns its id.
  Future<String> add(InventoryItem item, {required String uid}) async {
    final doc = _items.doc();
    await doc.set({..._fields(item), 'addedByUid': uid});
    return doc.id;
  }

  Future<void> update(InventoryItem item) =>
      _items.doc(item.id).update(_fields(item)..remove('addedAt'));

  Future<void> remove(String id) => _items.doc(id).delete();

  /// Marks history entries as put away, so the "just bought" prompt stops
  /// offering them -- whether they went into the inventory or were skipped.
  Future<void> markPutAway(Iterable<String> historyIds) async {
    final batch = _firestore.batch();
    for (final id in historyIds) {
      batch.set(_family.collection('groceryHistory').doc(id), {
        'putAwayAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// One-time move of the old Grocery tab's expiry list
  /// (`/groceryItems`: name + expiry date) into the inventory, so nothing
  /// tracked there is lost. Safe to call repeatedly: it empties the old
  /// collection as it goes.
  Future<void> importLegacyExpiryList() async {
    final old = await _family.collection('groceryItems').get();
    if (old.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in old.docs) {
      final data = doc.data();
      final name = (data['name'] as String?)?.trim() ?? 'Item';
      final match = searchCatalog(name).firstOrNull;
      final expiry = data['expiryDate'];
      batch.set(_items.doc(), {
        'name': name,
        'emoji': match?.emoji ?? '🥫',
        'category': (match?.category ?? GroceryCategory.other).name,
        'storage': defaultStorage(match).name,
        'catalogId': match?.id,
        'spec': '',
        'expiresAt': expiry is Timestamp ? expiry : null,
        'addedAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        'addedByUid': data['addedByUid'],
      });
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Map<String, Object?> _fields(InventoryItem item) => {
    'name': item.name,
    'emoji': item.emoji,
    'category': item.category.name,
    'storage': item.storage.name,
    'catalogId': item.catalogId,
    'spec': item.spec,
    'expiresAt': item.expiresAt == null
        ? null
        : Timestamp.fromDate(item.expiresAt!),
    'addedAt': FieldValue.serverTimestamp(),
  };

  static InventoryItem _from(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    DateTime? date(Object? v) => v is Timestamp ? v.toDate() : null;
    return InventoryItem(
      id: d.id,
      name: data['name'] as String? ?? 'Item',
      emoji: data['emoji'] as String? ?? '🥫',
      category:
          GroceryCategory.values.asNameMap()[data['category']] ??
          GroceryCategory.other,
      storage:
          StorageLocation.values.asNameMap()[data['storage']] ??
          StorageLocation.pantry,
      catalogId: data['catalogId'] as String?,
      spec: data['spec'] as String? ?? '',
      expiresAt: date(data['expiresAt']),
      addedAt: date(data['addedAt']),
    );
  }
}
