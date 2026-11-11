import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../grocery/providers/grocery_providers.dart';
import '../data/meal_plan_repository.dart';
import '../providers/meal_plan_providers.dart';

class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  Future<void> _editMeal(
    BuildContext context,
    WidgetRef ref,
    String dateKey,
    String mealType,
    String currentText,
  ) async {
    final controller = TextEditingController(text: currentText);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${mealType[0].toUpperCase()}${mealType.substring(1)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'What\'s the plan?'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (text == null) return;
    await ref
        .read(mealPlanRepositoryProvider)
        .setMeal(dateKey, mealType, text.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weekMealPlanProvider);
    final groceryAsync = ref.watch(groceryItemsProvider);
    final expiringSoon = (groceryAsync.value ?? const [])
        .where((item) => item.daysUntilExpiry() <= 3)
        .toList();

    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day + i),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Meal planning')),
      body: weekAsync.when(
        data: (plan) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (expiringSoon.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Use these up soon: '
                    '${expiringSoon.map((e) => e.name).join(', ')}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            for (final day in days) ...[
              Text(
                DateFormat.EEEE().format(day) == DateFormat.EEEE().format(today)
                    ? 'Today'
                    : DateFormat('EEEE, MMM d').format(day),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Builder(
                builder: (context) {
                  final dateKey = MealPlanRepository.keyFor(day);
                  final mealDay = plan[dateKey] ?? MealPlanDay(date: dateKey);
                  return Column(
                    children: [
                      _mealRow(
                        context,
                        ref,
                        dateKey,
                        'breakfast',
                        mealDay.breakfast,
                      ),
                      _mealRow(context, ref, dateKey, 'lunch', mealDay.lunch),
                      _mealRow(context, ref, dateKey, 'dinner', mealDay.dinner),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Something went wrong: $error')),
      ),
    );
  }

  Widget _mealRow(
    BuildContext context,
    WidgetRef ref,
    String dateKey,
    String mealType,
    String text,
  ) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${mealType[0].toUpperCase()}${mealType.substring(1)}'),
      subtitle: Text(text.isEmpty ? 'Tap to add' : text),
      onTap: () => _editMeal(context, ref, dateKey, mealType, text),
    );
  }
}
