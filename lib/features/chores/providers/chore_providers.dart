import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart' show familyIdProvider;
import '../../auth/providers/family_members_provider.dart';
import '../data/chore_repository.dart';
import '../models/chore.dart';

final choreRepositoryProvider = Provider<ChoreRepository>(
  (ref) => ChoreRepository(familyId: ref.watch(familyIdProvider)),
  dependencies: [familyIdProvider],
);

/// Open tasks, Reminders order: priority first, then by due date (undated
/// last), then by title.
final choresProvider = StreamProvider<List<Chore>>(
  (ref) => ref
      .watch(choreRepositoryProvider)
      .watchChores()
      .map(
        (chores) => chores
          ..sort((a, b) {
            if (a.priority != b.priority) return a.priority ? -1 : 1;
            final da = a.dueAt, db = b.dueAt;
            if (da != null && db != null && da != db) return da.compareTo(db);
            if ((da == null) != (db == null)) return da == null ? 1 : -1;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }),
      ),
  dependencies: [choreRepositoryProvider],
);

final choreLogProvider = StreamProvider<List<ChoreCompletion>>(
  (ref) => ref.watch(choreRepositoryProvider).watchLog(DateTime.now()),
  dependencies: [choreRepositoryProvider],
);

/// Names a task can be assigned to: family members, anyone already used
/// as an assignee, and "Partner" until a partner has joined.
final assigneeOptionsProvider = Provider<List<String>>((ref) {
  final members = ref.watch(familyMembersProvider).value?.values ?? const [];
  final used = [
    for (final c in ref.watch(choresProvider).value ?? const <Chore>[])
      ?c.assignee,
  ];
  final names = <String>{...members, ...used};
  if (names.length < 2) names.add('Partner');
  return names.toList()..sort();
}, dependencies: [familyMembersProvider, choresProvider]);
