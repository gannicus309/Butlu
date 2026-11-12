import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_providers.dart';
import '../../auth/providers/family_members_provider.dart';
import '../../bills/models/bill.dart';
import '../../bills/providers/bill_providers.dart';
import '../../calendar/models/calendar_category.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../chores/models/chore.dart';
import '../../chores/providers/chore_providers.dart';
import '../../family_notes/providers/family_notes_providers.dart';
import '../../grocery/models/shopping_item.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../meals/data/meal_plan_repository.dart';
import '../../meals/providers/meal_plan_providers.dart';

/// What Gemini is told about the family before each question: who they
/// are and what's in Butlu right now -- inventory, shopping list, chores,
/// the next two weeks of calendar, meal plan and bills. Office calendar
/// events go as "busy" only, without titles. The Vault is never included.
///
/// A plain-text snapshot, a few thousand characters at most. Anything
/// that can't be loaded within a few seconds is left out rather than
/// holding up the question.
const _office = {CalendarCategory.myOffice, CalendarCategory.partnerOffice};

Future<String> buildFamilyContext(WidgetRef ref) async {
  Future<T?> load<T>(ProviderListenable<Future<T>> p) => ref
      .read(p)
      .timeout(const Duration(seconds: 4))
      .then<T?>((v) => v)
      .catchError((Object _) => null);

  final results = await Future.wait([
    load(inventoryProvider.future),
    load(shoppingListProvider.future),
    load(choresProvider.future),
    load(eventsProvider.future),
    load(weekMealPlanProvider.future),
    load(billsProvider.future),
    load(familyMembersProvider.future),
    load(familyNotesProvider.future),
  ]);
  final inventory = results[0] as List<InventoryItem>? ?? const [];
  final shopping = results[1] as List<ShoppingItem>? ?? const [];
  final chores = results[2] as List<Chore>? ?? const [];
  final mealPlan = results[4] as Map<String, MealPlanDay>? ?? const {};
  final bills = results[5] as List<Bill>? ?? const [];
  final members = results[6] as Map<String, String>? ?? const {};
  final notes = (results[7] as String? ?? '').trim();
  final events = ref.read(mergedEventsProvider);
  final family = ref.read(familyDocProvider).value ?? const {};
  final me = ref.read(authStateProvider).value;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateFormat('EEE d MMM');
  final time = DateFormat('HH:mm');
  final b = StringBuffer()
    ..writeln(
      'You are Gemini inside Butlu, a family organiser app. Answer '
      'briefly and practically, like a helpful friend. Use the family\'s '
      'data below when it helps; it is current as of now. If something '
      'isn\'t in the data, say so rather than guessing. Use plain text '
      'with short lists; **bold** is fine.',
    )
    ..writeln()
    ..writeln('Now: ${DateFormat('EEEE d MMMM yyyy, HH:mm').format(now)}')
    ..writeln('Family: ${family['name'] ?? 'unknown'}')
    ..writeln(
      'Members: ${members.values.join(', ')}; '
      'asking: ${me?.displayName ?? 'a member'}',
    );

  if (notes.isNotEmpty) {
    b
      ..writeln()
      ..writeln('FAMILY NOTES (written by the family; follow them):')
      ..writeln(notes);
  }

  b
    ..writeln()
    ..writeln('INVENTORY (${inventory.length} items: fridge/freezer/pantry):');
  final byExpiry = [...inventory]
    ..sort(
      (a, c) => (a.expiresAt ?? DateTime(9999)).compareTo(
        c.expiresAt ?? DateTime(9999),
      ),
    );
  for (final i in byExpiry.take(150)) {
    final left = i.daysLeft(now);
    b.writeln(
      '- ${i.name}${i.spec.isEmpty ? '' : ' (${i.spec})'} · '
      '${i.storage.label}'
      '${i.expiresAt == null ? '' : ' · use by ${day.format(i.expiresAt!)}'
                ' (${left! < 0 ? '${-left} days past' : '$left days left'})'}',
    );
  }

  b
    ..writeln()
    ..writeln('SHOPPING LIST (${shopping.length}):');
  for (final s in shopping.take(100)) {
    b.writeln('- ${s.name}${s.spec.isEmpty ? '' : ' (${s.spec})'}');
  }

  b
    ..writeln()
    ..writeln('CHORES / TO-DOS (${chores.length}):');
  for (final c in chores.take(100)) {
    b.writeln(
      '- ${c.title}'
      '${c.dueAt == null ? '' : ' · due ${day.format(c.dueAt!)}'}'
      '${c.repeat == ChoreRepeat.none ? '' : ' · ${c.repeat.label}'}'
      '${c.priority ? ' · PRIORITY' : ''}'
      '${c.assignee == null ? '' : ' · for ${c.assignee}'}',
    );
  }

  final horizon = today.add(const Duration(days: 14));
  final upcoming = [
    for (final e in events)
      if (e.endAt.toLocal().isAfter(today) &&
          e.startAt.toLocal().isBefore(horizon))
        e,
  ]..sort((a, c) => a.startAt.compareTo(c.startAt));
  b
    ..writeln()
    ..writeln('CALENDAR, next 14 days:');
  for (final e in upcoming.take(120)) {
    final s = e.startAt.toLocal();
    b.writeln(
      '- ${day.format(s)} '
      '${e.isAllDay ? 'all day' : '${time.format(s)}-${time.format(e.endAt.toLocal())}'}'
      // Work meetings stay on the phone: only that someone is busy.
      ' · ${_office.contains(e.category) ? 'busy' : e.title}'
      '${e.category == null ? '' : ' [${e.category!.label}]'}',
    );
  }

  if (mealPlan.isNotEmpty) {
    b
      ..writeln()
      ..writeln('MEAL PLAN this week:');
    for (final entry in mealPlan.entries) {
      final m = entry.value;
      final meals = [
        if (m.breakfast.isNotEmpty) 'breakfast: ${m.breakfast}',
        if (m.lunch.isNotEmpty) 'lunch: ${m.lunch}',
        if (m.dinner.isNotEmpty) 'dinner: ${m.dinner}',
      ];
      if (meals.isNotEmpty) b.writeln('- ${entry.key}: ${meals.join('; ')}');
    }
  }

  if (bills.isNotEmpty) {
    b
      ..writeln()
      ..writeln('BILLS:');
    for (final bill in bills.take(50)) {
      b.writeln(
        '- ${bill.name}'
        '${bill.amount == null ? '' : ' · €${bill.amount}'}'
        ' · due ${day.format(bill.dueDate)}'
        '${bill.autoPay ? ' · auto-pay' : ''}',
      );
    }
  }
  return b.toString();
}
