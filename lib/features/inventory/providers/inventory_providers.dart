import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/expiry_notifier.dart';
import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../../grocery/models/shopping_item.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../data/inventory_repository.dart';
import '../models/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

/// Everything in the inventory, soonest to go off first; undated items last.
final inventoryProvider = StreamProvider<List<InventoryItem>>(
  (ref) => ref
      .watch(inventoryRepositoryProvider)
      .watch()
      .map(
        (items) => items
          ..sort((a, b) {
            final ea = a.expiresAt, eb = b.expiresAt;
            if (ea == null && eb == null) return a.name.compareTo(b.name);
            if (ea == null) return 1;
            if (eb == null) return -1;
            return ea.compareTo(eb);
          }),
      ),
  dependencies: [inventoryRepositoryProvider],
);

/// Shopping items ticked off in the last week and not put away yet.
final awaitingPutAwayProvider = Provider<List<GroceryHistoryEntry>>((ref) {
  final now = DateTime.now();
  return [
    for (final h in ref.watch(groceryHistoryProvider).value ?? const [])
      if (h.awaitingPutAway(now)) h,
  ];
}, dependencies: [groceryHistoryProvider]);

/// Overridden in main() with an initialised one; this default (tests) does
/// nothing.
final expiryNotifierProvider = Provider<ExpiryNotifier>(
  (ref) => ExpiryNotifier(),
);
