import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog.dart';
import '../models/shopping_item.dart';

/// The family's shared shopping list and its buying history, under
/// `/families/{familyId}/shoppingList` and `/groceryHistory`. Both phones
/// see changes live.
class ShoppingRepository {
  ShoppingRepository({required this.familyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _family =>
      _firestore.collection('families').doc(familyId);

  CollectionReference<Map<String, dynamic>> get _list =>
      _family.collection('shoppingList');

  CollectionReference<Map<String, dynamic>> get _history =>
      _family.collection('groceryHistory');

  Stream<List<ShoppingItem>> watchList() => _list.snapshots().map(
    (s) => s.docs.map((d) => _itemFrom(d.id, d.data())).toList()
      ..sort(
        (a, b) => (a.addedAt ?? DateTime.now()).compareTo(
          b.addedAt ?? DateTime.now(),
        ),
      ),
  );

  Stream<List<GroceryHistoryEntry>> watchHistory() => _history
      .orderBy('lastUsedAt', descending: true)
      .limit(60)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            GroceryHistoryEntry(
              item: _itemFrom(d.id, d.data()),
              lastUsedAt: _date(d.data()['lastUsedAt']) ?? DateTime.now(),
              lastBoughtAt: _date(d.data()['lastBoughtAt']),
              putAwayAt: _date(d.data()['putAwayAt']),
              timesBought: (d.data()['timesBought'] as num?)?.toInt() ?? 0,
            ),
        ],
      );

  Future<void> add(ShoppingItem item, {required String uid}) async {
    final batch = _firestore.batch()
      ..set(_list.doc(item.id), {
        ..._itemFields(item),
        'spec': item.spec,
        'addedByUid': uid,
        'addedAt': FieldValue.serverTimestamp(),
      })
      ..set(_history.doc(item.id), {
        ..._itemFields(item),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Ticks an item off: off the list, and counted as bought in the history.
  Future<void> markBought(ShoppingItem item) async {
    final batch = _firestore.batch()
      ..delete(_list.doc(item.id))
      ..set(_history.doc(item.id), {
        ..._itemFields(item),
        'lastUsedAt': FieldValue.serverTimestamp(),
        'lastBoughtAt': FieldValue.serverTimestamp(),
        'timesBought': FieldValue.increment(1),
      }, SetOptions(merge: true));
    // Bought a supply that was running low: it's stocked again.
    final low = await _family
        .collection('inventory')
        .where('low', isEqualTo: true)
        .get();
    for (final doc in low.docs) {
      final name = (doc.data()['name'] as String? ?? '').toLowerCase();
      if (name == item.name.toLowerCase() ||
          (item.catalogItem != null &&
              doc.data()['catalogId'] == item.catalogItem!.id)) {
        batch.update(doc.reference, {'low': false});
      }
    }
    await batch.commit();
  }

  /// Takes an item off without counting it as bought (added by mistake).
  Future<void> remove(String itemId) => _list.doc(itemId).delete();

  /// Removes an item from the history, so it stops showing as recently used.
  Future<void> forget(String itemId) => _history.doc(itemId).delete();

  Future<void> setSpec(String itemId, String spec) =>
      _list.doc(itemId).update({'spec': spec.trim()});

  /// Puts back an item that was just ticked off by mistake. Leaves the
  /// bought count as it was -- close enough for a "recently used" list.
  Future<void> undoBought(ShoppingItem item, {required String uid}) =>
      add(item, uid: uid);

  Map<String, Object?> _itemFields(ShoppingItem item) => {
    'name': item.name,
    'emoji': item.emoji,
    'category': item.category.name,
  };

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  static ShoppingItem _itemFrom(String id, Map<String, dynamic> data) =>
      ShoppingItem(
        id: id,
        name: data['name'] as String? ?? id,
        emoji: data['emoji'] as String? ?? '🛒',
        category:
            GroceryCategory.values.asNameMap()[data['category']] ??
            GroceryCategory.other,
        spec: data['spec'] as String? ?? '',
        addedByUid: data['addedByUid'] as String?,
        // A just-added item's server timestamp reads back as null until the
        // server confirms it; it sorts as "now" until then.
        addedAt: _date(data['addedAt']),
      );
}
