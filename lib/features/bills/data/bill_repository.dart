import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill.dart';

/// Shared-family bills/subscriptions, backed by `/families/{familyId}/bills`.
class BillRepository {
  BillRepository({required this.familyId, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bills =>
      _firestore.collection('families').doc(familyId).collection('bills');

  Stream<List<Bill>> watchBills() {
    return _bills.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(_fromDoc).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
    );
  }

  Future<void> addBill({
    required String name,
    required double? amount,
    required DateTime dueDate,
    required bool autoPay,
    required String createdByUid,
  }) async {
    await _bills.add({
      'name': name,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'autoPay': autoPay,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBill(String billId) async {
    await _bills.doc(billId).delete();
  }

  Bill _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Bill(
      id: doc.id,
      name: data['name'] as String,
      amount: (data['amount'] as num?)?.toDouble(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      autoPay: data['autoPay'] as bool? ?? false,
      createdByUid: data['createdByUid'] as String,
    );
  }
}
