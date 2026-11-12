import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../../chores/models/chore.dart';
import '../../chores/providers/chore_providers.dart';
import '../../grocery/models/catalog.dart';
import '../../grocery/models/shopping_item.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../../inventory/models/inventory_item.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../meals/data/meal_plan_repository.dart';
import '../../meals/providers/meal_plan_providers.dart';

/// What Gemini may propose doing in Butlu. It never acts by itself: each
/// proposal shows as a card, and nothing changes until someone taps
/// "Do it".
const kGeminiFunctions = <Map<String, Object?>>[
  {
    'name': 'add_to_shopping_list',
    'description':
        'Propose adding items to the family shopping list. Use short, '
        'everyday names ("Eggs", "Greek yogurt").',
    'parameters': {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': ['items'],
    },
  },
  {
    'name': 'add_chore',
    'description': 'Propose a new to-do on the family Chores list.',
    'parameters': {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'due_date': {'type': 'string', 'description': 'YYYY-MM-DD, optional'},
        'repeat': {
          'type': 'string',
          'enum': ['none', 'daily', 'weekly', 'biweekly', 'monthly'],
        },
        'assignee': {
          'type': 'string',
          'description': 'A family member\'s name, optional',
        },
        'priority': {'type': 'boolean'},
        'subtype': {
          'type': 'string',
          'enum': ['house', 'admin', 'butlu', 'personal', 'office'],
        },
      },
      'required': ['title'],
    },
  },
  {
    'name': 'plan_meal',
    'description': 'Propose putting a meal on the family meal plan.',
    'parameters': {
      'type': 'object',
      'properties': {
        'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'meal': {
          'type': 'string',
          'enum': ['breakfast', 'lunch', 'dinner'],
        },
        'dish': {'type': 'string'},
      },
      'required': ['date', 'meal', 'dish'],
    },
  },
  {
    'name': 'use_up_inventory',
    'description':
        'Propose marking inventory items as used up (e.g. after cooking), '
        'optionally putting them back on the shopping list.',
    'parameters': {
      'type': 'object',
      'properties': {
        'names': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Names exactly as in the inventory',
        },
        'add_to_shopping_list': {'type': 'boolean'},
      },
      'required': ['names'],
    },
  },
  {
    'name': 'update_inventory_item',
    'description':
        'Propose changing one inventory item: its use-by date, where it is '
        'kept, or its name.',
    'parameters': {
      'type': 'object',
      'properties': {
        'name': {
          'type': 'string',
          'description': 'Name exactly as in the inventory',
        },
        'use_by': {'type': 'string', 'description': 'YYYY-MM-DD'},
        'storage': {
          'type': 'string',
          'enum': ['fridge', 'freezer', 'pantry', 'household'],
        },
        'new_name': {'type': 'string'},
      },
      'required': ['name'],
    },
  },
];

/// One action Gemini proposed, and what became of it.
class ProposedAction {
  ProposedAction(this.name, this.args);

  final String name;
  final Map<String, dynamic> args;
  ActionState state = ActionState.pending;

  /// What happened, once done (or why it failed).
  String? outcome;

  List<String> _list(String key) =>
      [for (final v in args[key] as List? ?? const []) '$v'.trim()]
        ..removeWhere((s) => s.isEmpty);

  DateTime? _date(String key) => DateTime.tryParse('${args[key] ?? ''}');

  IconData get icon => switch (name) {
    'add_to_shopping_list' => Icons.add_shopping_cart,
    'add_chore' => Icons.task_alt,
    'plan_meal' => Icons.restaurant_menu,
    'use_up_inventory' => Icons.check_circle_outline,
    'update_inventory_item' => Icons.edit_outlined,
    _ => Icons.bolt,
  };

  /// One line saying what will happen.
  String get summary {
    final day = DateFormat('EEE d MMM');
    switch (name) {
      case 'add_to_shopping_list':
        return 'Add to shopping list: ${_list('items').join(', ')}';
      case 'add_chore':
        final due = _date('due_date');
        final repeat = ChoreRepeat.values.asNameMap()[args['repeat']];
        return 'New chore: ${args['title']}'
            '${due == null ? '' : ' · ${day.format(due)}'}'
            '${repeat == null || repeat == ChoreRepeat.none ? '' : ' · ${repeat.label}'}'
            '${args['assignee'] == null ? '' : ' · for ${args['assignee']}'}';
      case 'plan_meal':
        final date = _date('date');
        return 'Meal plan: ${args['dish']} for ${args['meal']}'
            '${date == null ? '' : ', ${day.format(date)}'}';
      case 'use_up_inventory':
        return 'Used up: ${_list('names').join(', ')}'
            '${args['add_to_shopping_list'] == true ? ' (and buy again)' : ''}';
      case 'update_inventory_item':
        final useBy = _date('use_by');
        final changes = [
          if (args['new_name'] != null) 'rename to ${args['new_name']}',
          if (useBy != null) 'use by ${day.format(useBy)}',
          if (args['storage'] != null) 'move to ${args['storage']}',
        ];
        return 'Change ${args['name']}: ${changes.join(', ')}';
      default:
        return 'Unknown action: $name';
    }
  }

  /// For the conversation history, so Gemini knows what was done.
  String get historyNote => '[$summary -- ${state.name}]';
}

enum ActionState { pending, done, skipped, failed }

/// Carries out [action] in Butlu. Returns what was done; throws with a
/// readable message when it can't be.
Future<String> runGeminiAction(WidgetRef ref, ProposedAction action) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) throw StateError('Not signed in');
  final a = action.args;

  ShoppingItem shoppingFor(String name) {
    final match = searchCatalog(name).firstOrNull;
    return match != null && match.name.toLowerCase() == name.toLowerCase()
        ? ShoppingItem.fromCatalog(match)
        : ShoppingItem.custom(name);
  }

  Future<List<InventoryItem>> inventory() => ref.read(inventoryProvider.future);

  InventoryItem? find(List<InventoryItem> items, String name) {
    final n = name.toLowerCase().trim();
    return items.where((i) => i.name.toLowerCase() == n).firstOrNull ??
        items.where((i) => i.name.toLowerCase().contains(n)).firstOrNull ??
        items.where((i) => n.contains(i.name.toLowerCase())).firstOrNull;
  }

  switch (action.name) {
    case 'add_to_shopping_list':
      final names = action._list('items');
      final onList = {
        for (final s in await ref.read(shoppingListProvider.future))
          s.name.toLowerCase(),
      };
      final added = <String>[];
      for (final n in names) {
        final item = shoppingFor(n);
        if (onList.contains(item.name.toLowerCase())) continue;
        await ref.read(shoppingRepositoryProvider).add(item, uid: uid);
        added.add(item.name);
      }
      return added.isEmpty
          ? 'Already on the list'
          : 'Added ${added.join(', ')}';

    case 'add_chore':
      await ref
          .read(choreRepositoryProvider)
          .save(
            Chore(
              id: '',
              title: '${a['title']}',
              dueAt: action._date('due_date'),
              repeat:
                  ChoreRepeat.values.asNameMap()[a['repeat']] ??
                  ChoreRepeat.none,
              assignee: a['assignee'] as String?,
              priority: a['priority'] == true,
              subtype:
                  ChoreSubtype.values.asNameMap()[a['subtype']] ??
                  ChoreSubtype.house,
            ),
            uid: uid,
          );
      return 'Added to Chores';

    case 'plan_meal':
      final date = action._date('date');
      final meal = '${a['meal']}';
      if (date == null || !['breakfast', 'lunch', 'dinner'].contains(meal)) {
        throw StateError('Needs a date and a meal');
      }
      await ref
          .read(mealPlanRepositoryProvider)
          .setMeal(MealPlanRepository.keyFor(date), meal, '${a['dish']}');
      return 'On the meal plan';

    case 'use_up_inventory':
      final items = await inventory();
      final done = <String>[];
      final missing = <String>[];
      for (final n in action._list('names')) {
        final item = find(items, n);
        if (item == null) {
          missing.add(n);
          continue;
        }
        await ref.read(inventoryRepositoryProvider).remove(item.id);
        if (a['add_to_shopping_list'] == true) {
          final catalog = kCatalogById[item.catalogId];
          await ref
              .read(shoppingRepositoryProvider)
              .add(
                catalog != null
                    ? ShoppingItem.fromCatalog(catalog)
                    : ShoppingItem.custom(item.name),
                uid: uid,
              );
        }
        done.add(item.name);
      }
      if (done.isEmpty) throw StateError('Not in the inventory: $missing');
      return 'Used up ${done.join(', ')}'
          '${missing.isEmpty ? '' : ' (not found: ${missing.join(', ')})'}';

    case 'update_inventory_item':
      final item = find(await inventory(), '${a['name']}');
      if (item == null) throw StateError('No "${a['name']}" in the inventory');
      final useBy = action._date('use_by');
      final storage = StorageLocation.values.asNameMap()[a['storage']];
      final newName = '${a['new_name'] ?? ''}'.trim();
      await ref
          .read(inventoryRepositoryProvider)
          .update(
            item.copyWith(
              name: newName.isEmpty ? null : newName,
              expiresAt: useBy,
              storage: storage,
            ),
          );
      return 'Updated ${item.name}';
  }
  throw StateError('Butlu can\'t do "${action.name}" yet');
}
