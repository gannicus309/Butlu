import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/meal_plan_repository.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>(
  (ref) => MealPlanRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

final weekMealPlanProvider = StreamProvider<Map<String, MealPlanDay>>(
  (ref) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 6));
    return ref.watch(mealPlanRepositoryProvider).watchWeek(start, end);
  },
  dependencies: [mealPlanRepositoryProvider],
);
