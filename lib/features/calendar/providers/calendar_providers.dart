import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_event.dart';
import '../models/event_source.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Milestone 1 stand-in for the real merged event stream (Firestore + the
/// two external calendars). Replaced by a provider over
/// [CalendarSyncService]/[FirestoreEventRepository] in Milestone 2 once a
/// real Firebase project exists -- the UI below only depends on
/// [eventsByDayProvider], so that swap won't touch any screen or widget.
final mockEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final now = DateTime.now();
  DateTime at(int dayOffset, int hour, [int minute = 0]) => DateTime(
        now.year,
        now.month,
        now.day + dayOffset,
        hour,
        minute,
      ).toUtc();

  DateTime nowUtc() => DateTime.now().toUtc();

  return [
    CalendarEvent(
      id: 'mock-1',
      title: "Pediatrician checkup",
      notes: "Bring the vaccination booklet",
      startAt: at(0, 9, 30),
      endAt: at(0, 10, 15),
      timeZone: 'local',
      source: EventSource.outlook,
      createdByUid: 'mock-wife',
      outlookRef: const ExternalRef(eventIdentifier: 'mock-graph-1'),
      lastModifiedAt: nowUtc(),
      lastModifiedBy: EventSource.outlook,
    ),
    CalendarEvent(
      id: 'mock-2',
      title: 'Date night',
      startAt: at(1, 19),
      endAt: at(1, 21, 30),
      timeZone: 'local',
      source: EventSource.butlu,
      createdByUid: 'mock-husband',
      lastModifiedAt: nowUtc(),
      lastModifiedBy: EventSource.butlu,
    ),
    CalendarEvent(
      id: 'mock-3',
      title: "Nursery drop-off",
      startAt: at(1, 8),
      endAt: at(1, 8, 30),
      timeZone: 'local',
      source: EventSource.ios,
      createdByUid: 'mock-husband',
      iosRef: const ExternalRef(eventIdentifier: 'mock-ekevent-1'),
      lastModifiedAt: nowUtc(),
      lastModifiedBy: EventSource.ios,
    ),
    CalendarEvent(
      id: 'mock-4',
      title: "Grandma's birthday",
      startAt: at(4, 0),
      endAt: at(4, 23, 59),
      isAllDay: true,
      timeZone: 'local',
      source: EventSource.outlook,
      createdByUid: 'mock-wife',
      outlookRef: const ExternalRef(eventIdentifier: 'mock-graph-2'),
      lastModifiedAt: nowUtc(),
      lastModifiedBy: EventSource.outlook,
    ),
    CalendarEvent(
      id: 'mock-5',
      title: 'Team standup',
      startAt: at(2, 9),
      endAt: at(2, 9, 15),
      timeZone: 'local',
      source: EventSource.outlook,
      createdByUid: 'mock-wife',
      outlookRef: const ExternalRef(eventIdentifier: 'mock-graph-3'),
      lastModifiedAt: nowUtc(),
      lastModifiedBy: EventSource.outlook,
    ),
    CalendarEvent(
      id: 'mock-6',
      title: 'Family walk',
      startAt: at(-2, 17),
      endAt: at(-2, 18),
      timeZone: 'local',
      source: EventSource.ios,
      createdByUid: 'mock-husband',
      iosRef: const ExternalRef(eventIdentifier: 'mock-ekevent-2'),
      lastModifiedAt: nowUtc(),
      lastModifiedBy: EventSource.ios,
    ),
  ];
});

final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// Events grouped by calendar day (local time, midnight-keyed) -- the shape
/// `table_calendar`'s `eventLoader` and the day-detail screen both want.
final eventsByDayProvider = Provider<Map<DateTime, List<CalendarEvent>>>((ref) {
  final events = ref.watch(mockEventsProvider);
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
});

final eventsForDayProvider = Provider.family<List<CalendarEvent>, DateTime>(
  (ref, day) => ref.watch(eventsByDayProvider)[_dateOnly(day)] ?? const [],
);
