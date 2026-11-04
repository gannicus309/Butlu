import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart'
    show authStateProvider, familyIdProvider;
import '../data/firestore_event_repository.dart';
import '../data/firestore_event_repository_impl.dart';
import '../data/ios_calendar_repository.dart';
import '../data/ios_calendar_repository_impl.dart';
import '../../../services/clash_notifier.dart';
import '../models/calendar_event.dart';
import '../models/conflicts.dart';
import '../models/event_dedupe.dart';
import '../sync/calendar_sync_service.dart';
import 'calendar_selection_provider.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// `dependencies` matters here: `familyIdProvider` is overridden in a nested
// ProviderScope (see main.dart's `_FamilyGate`), created only once a family
// is resolved. Every provider below that transitively reads it must declare
// that in `dependencies`, or Riverpod resolves it against the wrong
// (unscoped, root) container and throws a "read from a place where one of
// its dependencies were overridden" assertion.
final firestoreEventRepositoryProvider = Provider<FirestoreEventRepository>((
  ref,
) {
  final familyId = ref.watch(familyIdProvider);
  return FirestoreEventRepositoryImpl(familyId: familyId);
}, dependencies: [familyIdProvider]);

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
/// Live events with deleted ones dropped and cross-calendar duplicates
/// merged -- what every calendar view and the clash check work from.
final mergedEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final events = ref.watch(eventsProvider).value ?? const [];
  return mergeDuplicates([
    for (final e in events)
      if (!e.deleted) e,
  ]);
}, dependencies: [eventsProvider]);

/// Clashes in the next 30 days, for notifications.
final upcomingConflictsProvider = Provider<List<EventConflict>>((ref) {
  final now = DateTime.now();
  return findConflicts(
    ref.watch(mergedEventsProvider),
    from: now,
    to: now.add(const Duration(days: 30)),
  );
}, dependencies: [mergedEventsProvider]);

/// Overridden in main() with one that's been initialised; this default
/// (used by tests) is never initialised, so it silently does nothing.
final clashNotifierProvider = Provider<ClashNotifier>(
  (ref) => ClashNotifier(ref.watch(sharedPreferencesProvider)),
);

final eventsByDayProvider = Provider<Map<DateTime, List<CalendarEvent>>>((ref) {
  final map = <DateTime, List<CalendarEvent>>{};
  for (final event in ref.watch(mergedEventsProvider)) {
    // Filed under every day it covers, so an event running past midnight or
    // a multi-day all-day event shows on each of its days. The end is
    // exclusive: an all-day event ends at the next midnight.
    final first = _dateOnly(event.startAt.toLocal());
    final lastMoment = event.endAt.toLocal().subtract(
      const Duration(microseconds: 1),
    );
    final last = lastMoment.isBefore(event.startAt.toLocal())
        ? first
        : _dateOnly(lastMoment);
    for (
      var day = first, n = 0;
      !day.isAfter(last) && n < 62;
      day = DateTime(day.year, day.month, day.day + 1), n++
    ) {
      map.putIfAbsent(day, () => []).add(event);
    }
  }
  for (final list in map.values) {
    list.sort((a, b) => a.startAt.compareTo(b.startAt));
  }
  return map;
}, dependencies: [mergedEventsProvider]);

final eventsForDayProvider = Provider.family<List<CalendarEvent>, DateTime>(
  (ref, day) => ref.watch(eventsByDayProvider)[_dateOnly(day)] ?? const [],
  dependencies: [eventsByDayProvider],
);

final iosCalendarRepositoryProvider = Provider<IosCalendarRepository>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid ?? '';
  return IosCalendarRepositoryImpl(
    currentUid: uid,
    excludedCalendarIds: ref.watch(calendarSelectionProvider),
    calendarRoles: ref.watch(calendarRolesProvider),
  );
});

/// No `outlook` repository yet -- see [CalendarSyncService]'s doc comment on
/// why that's fine for now. Run by the Calendar tab when it opens, when the
/// app comes back to the foreground, after the calendar picker changes, and
/// from its sync button.
/// The phone's calendars, for the picker. Re-fetched each time the picker
/// opens (autoDispose), so a newly accepted shared calendar shows up.
///
/// Its own repository instance rather than [iosCalendarRepositoryProvider]:
/// that one is rebuilt whenever a calendar is switched on/off or recoloured,
/// which would reload this list on every toggle and jump the picker back to
/// the top mid-scroll.
final deviceCalendarsProvider = FutureProvider.autoDispose(
  (ref) => IosCalendarRepositoryImpl(currentUid: '').listCalendars(),
);

/// Outcome of the Calendar tab's most recent sync, shown in the picker.
class CalendarSyncReport {
  const CalendarSyncReport({
    required this.at,
    this.eventsPerCalendar = const {},
    this.error,
  });

  final DateTime at;
  final Map<String, int> eventsPerCalendar;

  /// Set when the sync failed; [eventsPerCalendar] is then empty.
  final String? error;
}

final lastCalendarSyncProvider = StateProvider<CalendarSyncReport?>(
  (ref) => null,
);

final calendarSyncServiceProvider = Provider<CalendarSyncService>(
  (ref) => CalendarSyncService(
    firestore: ref.watch(firestoreEventRepositoryProvider),
    ios: ref.watch(iosCalendarRepositoryProvider),
  ),
  dependencies: [
    firestoreEventRepositoryProvider,
    iosCalendarRepositoryProvider,
  ],
);
