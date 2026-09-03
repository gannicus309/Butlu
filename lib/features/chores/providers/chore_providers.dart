import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../data/chore_repository.dart';
import '../models/chore_task.dart';

final choreRepositoryProvider = Provider<ChoreRepository>(
  (ref) => ChoreRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

final choreTasksProvider = StreamProvider<List<ChoreTask>>(
  (ref) => ref.watch(choreRepositoryProvider).watchTasks(),
  dependencies: [choreRepositoryProvider],
);

/// Static starter suggestions -- a fixed, generic set for now rather than
/// anything smarter (frequency-based, seasonal, etc.), which would need
/// usage history this app doesn't track yet.
const List<String> choreSuggestions = [
  "Pick up the kids",
  'Take out the trash',
  'Grocery run',
  'Dishes',
  'Laundry',
  'Vacuum',
];
