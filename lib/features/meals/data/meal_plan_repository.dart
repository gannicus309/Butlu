import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// A single day's meal plan: breakfast/lunch/dinner free-text, keyed by
/// `date` (already in `yyyy-MM-dd` form, matching the Firestore doc id).
class MealPlanDay {
  final String date;
  final String breakfast;
  final String lunch;
  final String dinner;

  const MealPlanDay({
    required this.date,
    this.breakfast = '',
    this.lunch = '',
    this.dinner = '',
  });
}

/// Shared-family weekly meal plan, backed by
/// `/families/{familyId}/mealPlan/{yyyy-MM-dd}`. Document ids are date
/// strings, which sort lexicographically the same as chronologically, so a
/// week window is a plain document-id range query -- no date field needed.
class MealPlanRepository {
  MealPlanRepository({required this.familyId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String familyId;
  final FirebaseFirestore _firestore;

  static final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');

  static String keyFor(DateTime date) => _keyFormat.format(date);

  CollectionReference<Map<String, dynamic>> get _days =>
      _firestore.collection('families').doc(familyId).collection('mealPlan');

  Stream<Map<String, MealPlanDay>> watchWeek(DateTime start, DateTime end) {
    return _days
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: keyFor(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: keyFor(end))
        .snapshots()
        .map(
          (snapshot) => {
            for (final doc in snapshot.docs) doc.id: _fromDoc(doc),
          },
        );
  }

  Future<void> setMeal(String dateKey, String mealType, String text) async {
    await _days.doc(dateKey).set({mealType: text}, SetOptions(merge: true));
  }

  MealPlanDay _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return MealPlanDay(
      date: doc.id,
      breakfast: data['breakfast'] as String? ?? '',
      lunch: data['lunch'] as String? ?? '',
      dinner: data['dinner'] as String? ?? '',
    );
  }
}
