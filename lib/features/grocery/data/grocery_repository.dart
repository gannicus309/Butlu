import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grocery_item.dart';

/// Shared-family grocery list, backed by
/// `/families/{familyId}/groceryItems`. No abstract interface/fake split
/// here unlike the calendar feature -- there's no merge algorithm to unit
/// test in isolation, just CRUD, so a concrete Firestore class is enough.
class GroceryRepository {
  GroceryRepository({required this.familyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _items => _firestore
      .collection('families')
      .doc(familyId)
      .collection('groceryItems');

  Stream<List<GroceryItem>> watchItems() {
    return _items.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(_fromDoc).toList()
            ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate)),
    );
  }

  Future<void> addItem({
    required String name,
    required DateTime expiryDate,
    required String addedByUid,
  }) async {
    await _items.add({
      'name': name,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'addedByUid': addedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String itemId) async {
    await _items.doc(itemId).delete();
  }

  GroceryItem _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return GroceryItem(
      id: doc.id,
      name: data['name'] as String,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      addedByUid: data['addedByUid'] as String,
      // Freshly-added docs read back their serverTimestamp as null in the
      // brief window before the server round-trips it.
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }
}
