import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart'
    show authStateProvider, familyIdProvider;
import '../data/firestore_event_repository.dart';
import '../data/firestore_event_repository_impl.dart';
import '../data/ios_calendar_repository.dart';
import '../data/ios_calendar_repository_impl.dart';
import '../models/calendar_event.dart';
import '../sync/calendar_sync_service.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// `dependencies` matters here: `familyIdProvider` is overridden in a nested
// ProviderScope (see main.dart's `_FamilyGate`), created only once a family
// is resolved. Every provider below that transitively reads it must declare
// that in `dependencies`, or Riverpod resolves it against the wrong
// (unscoped, root) container and throws a "read from a place where one of
// its dependencies were overridden" assertion.
final firestoreEventRepositoryProvider = Provider<FirestoreEventRepository>(
  (ref) {
    final familyId = ref.watch(familyIdProvider);
    return FirestoreEventRepositoryImpl(familyId: familyId);
  },
  dependencies: [familyIdProvider],
);

/// The shared family's live event stream. Overridden in widget tests with a
/// fake repository so the UI is testable without a real Firebase project.
final eventsProvider = StreamProvider<List<CalendarEvent>>(
  (ref) => ref.watch(firestoreEventRepositoryProvider).watchEvents(),
  dependencies: [firestoreEventRepositoryProvider],
);

final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// Events grouped by calendar day (local time, midnight-keyed) -- the shape
/// `table_calendar`'s `eventLoader` and the day-detail screen both want.
final eventsByDayProvider = Provider<Map<DateTime, List<CalendarEvent>>>(
  (ref) {
    final events = ref.watch(eventsProvider).value ?? const [];
    final map = <DateTime, List<CalendarEvent>>{};
    for (final event in events) {
      if (event.deleted) continue;
      final key = _dateOnly(event.startAt.toLocal());
      map.putIfAbsent(key, () => []).add(event);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
    }
    return map;
  },
  dependencies: [eventsProvider],
);

final eventsForDayProvider = Provider.family<List<CalendarEvent>, DateTime>(
  (ref, day) => ref.watch(eventsByDayProvider)[_dateOnly(day)] ?? const [],
  dependencies: [eventsByDayProvider],
);

final iosCalendarRepositoryProvider = Provider<IosCalendarRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid ?? '';
  return IosCalendarRepositoryImpl(currentUid: uid);
});

/// No `outlook` repository yet -- see [CalendarSyncService]'s doc comment on
/// why that's fine for now. Manually triggered (see the Calendar tab's
/// refresh button) rather than run automatically, since it can't be
/// exercised without a real iOS device/simulator to test against.
final calendarSyncServiceProvider = Provider<CalendarSyncService>(
  (ref) => CalendarSyncService(
    firestore: ref.watch(firestoreEventRepositoryProvider),
    ios: ref.watch(iosCalendarRepositoryProvider),
  ),
  dependencies: [firestoreEventRepositoryProvider, iosCalendarRepositoryProvider],
);
