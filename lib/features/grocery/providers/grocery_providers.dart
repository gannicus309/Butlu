import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/grocery_repository.dart';
import '../models/grocery_item.dart';

// See calendar_providers.dart for why `dependencies` matters: familyIdProvider
// is overridden in a nested ProviderScope once a family is resolved, and
// every provider that transitively reads it must declare that.
final groceryRepositoryProvider = Provider<GroceryRepository>(
  (ref) => GroceryRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

final groceryItemsProvider = StreamProvider<List<GroceryItem>>(
  (ref) => ref.watch(groceryRepositoryProvider).watchItems(),
  dependencies: [groceryRepositoryProvider],
);
