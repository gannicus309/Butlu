import 'package:butlu/features/calendar/data/external_calendar_repository.dart';
import 'package:butlu/features/calendar/data/firestore_event_repository.dart';
import 'package:butlu/features/calendar/data/ios_calendar_repository.dart';
import 'package:butlu/features/calendar/data/outlook_calendar_repository.dart';
import 'package:butlu/features/calendar/models/calendar_event.dart';
import 'package:butlu/features/calendar/models/event_source.dart';
import 'package:butlu/features/calendar/sync/calendar_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirestoreEventRepository implements FirestoreEventRepository {
  final Map<String, CalendarEvent> store = {};

  @override
  Stream<List<CalendarEvent>> watchEvents() =>
      Stream.value(store.values.toList());

  @override
  Future<List<CalendarEvent>> fetchAll() async => store.values.toList();

  @override
  Future<CalendarEvent?> findByExternalId({
    required EventSource source,
    required String externalId,
  }) async {
    for (final event in store.values) {
      final ref = event.refFor(source);
      if (ref?.eventIdentifier == externalId) return event;
    }
    return null;
  }

  @override
  Future<void> upsert(CalendarEvent event) async {
    store[event.id] = event;
  }

  @override
  Future<void> softDelete(String eventId) async {
    final existing = store[eventId];
    if (existing != null) {
      store[eventId] = existing.copyWith(deleted: true);
    }
  }
}

/// Fake for either external source; the sync engine only depends on
/// [ExternalCalendarRepository], so one fake implements both interfaces to
/// avoid duplicating call-tracking logic per source.
class FakeExternalRepository
    implements IosCalendarRepository, OutlookCalendarRepository {
  FakeExternalRepository(this.source);

  @override
  final EventSource source;

  List<CalendarEvent> windowResult = [];
  final List<CalendarEvent> createdEvents = [];
  final List<CalendarEvent> updatedEvents = [];
  int _nextCreatedId = 0;

  @override
  Future<List<CalendarEvent>> fetchWindow(DateTime start, DateTime end) async =>
      windowResult;

  @override
  Future<ExternalRef> createEvent(CalendarEvent event) async {
    createdEvents.add(event);
    return ExternalRef(eventIdentifier: 'generated-${_nextCreatedId++}');
  }

  @override
  Future<void> updateEvent(ExternalRef ref, CalendarEvent event) async {
    updatedEvents.add(event);
  }

  @override
  Future<void> deleteEvent(ExternalRef ref) async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<void> signIn() async {}

  @override
  Future<({List<CalendarEvent> events, String nextDeltaLink})> fetchDelta(
    String deltaLink,
  ) async =>
      (events: windowResult, nextDeltaLink: deltaLink);

  @override
  Future<String> fetchInitialDeltaLink(DateTime start, DateTime end) async =>
      'delta-token';
}

CalendarEvent _event({
  required String id,
  String title = 'Untitled',
  required EventSource source,
  required EventSource lastModifiedBy,
  required DateTime lastModifiedAt,
  ExternalRef? iosRef,
  ExternalRef? outlookRef,
  bool deleted = false,
}) {
  final start = DateTime.utc(2026, 9, 1, 10);
  return CalendarEvent(
    id: id,
    title: title,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    timeZone: 'UTC',
    source: source,
    createdByUid: 'uid-1',
    iosRef: iosRef,
    outlookRef: outlookRef,
    lastModifiedAt: lastModifiedAt,
    lastModifiedBy: lastModifiedBy,
    deleted: deleted,
  );
}

void main() {
  late FakeFirestoreEventRepository firestore;
  late FakeExternalRepository ios;
  late FakeExternalRepository outlook;
  late CalendarSyncService sync;

  setUp(() {
    firestore = FakeFirestoreEventRepository();
    ios = FakeExternalRepository(EventSource.ios);
    outlook = FakeExternalRepository(EventSource.outlook);
    sync = CalendarSyncService(
      firestore: firestore,
      ios: ios,
      outlook: outlook,
      now: () => DateTime.utc(2026, 9, 1),
    );
  });

  test('new external event is ingested into Firestore', () async {
    outlook.windowResult = [
      _event(
        id: 'ext-1',
        title: 'Dentist',
        source: EventSource.outlook,
        lastModifiedBy: EventSource.outlook,
        lastModifiedAt: DateTime.utc(2026, 8, 20),
        outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
      ),
    ];

    await sync.runFullSync();

    expect(firestore.store.length, 1);
    final stored = firestore.store.values.single;
    expect(stored.title, 'Dentist');
    expect(stored.source, EventSource.outlook);
    expect(stored.outlookRef?.eventIdentifier, 'graph-1');
  });

  test('newer external edit overwrites the stored event', () async {
    firestore.store['doc-1'] = _event(
      id: 'doc-1',
      title: 'Old title',
      source: EventSource.outlook,
      lastModifiedBy: EventSource.outlook,
      lastModifiedAt: DateTime.utc(2026, 8, 1),
      outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
    );
    outlook.windowResult = [
      _event(
        id: 'doc-1',
        title: 'New title',
        source: EventSource.outlook,
        lastModifiedBy: EventSource.outlook,
        lastModifiedAt: DateTime.utc(2026, 8, 20),
        outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
      ),
    ];

    await sync.runFullSync();

    expect(firestore.store['doc-1']!.title, 'New title');
  });

  test('stale external pull does not overwrite a newer local edit', () async {
    firestore.store['doc-1'] = _event(
      id: 'doc-1',
      title: 'Edited in Butlu',
      source: EventSource.outlook,
      lastModifiedBy: EventSource.butlu,
      lastModifiedAt: DateTime.utc(2026, 8, 25),
      outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
    );
    outlook.windowResult = [
      _event(
        id: 'doc-1',
        title: 'Stale title from Outlook',
        source: EventSource.outlook,
        lastModifiedBy: EventSource.outlook,
        lastModifiedAt: DateTime.utc(2026, 8, 1),
        outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
      ),
    ];

    await sync.runFullSync();

    expect(firestore.store['doc-1']!.title, 'Edited in Butlu');
  });

  test(
    'an event just pulled from Outlook is not echoed back out to iOS in the same cycle',
    () async {
      outlook.windowResult = [
        _event(
          id: 'ext-1',
          title: 'Dentist',
          source: EventSource.outlook,
          lastModifiedBy: EventSource.outlook,
          lastModifiedAt: DateTime.utc(2026, 8, 20),
          outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
        ),
      ];

      await sync.runFullSync();

      expect(ios.createdEvents, isEmpty);
      expect(outlook.createdEvents, isEmpty);
    },
  );

  test('a Butlu-native event is pushed out to both external calendars',
      () async {
    firestore.store['doc-1'] = _event(
      id: 'doc-1',
      title: 'Family dinner',
      source: EventSource.butlu,
      lastModifiedBy: EventSource.butlu,
      lastModifiedAt: DateTime.utc(2026, 8, 30),
    );

    await sync.runFullSync();

    expect(ios.createdEvents, hasLength(1));
    expect(outlook.createdEvents, hasLength(1));
    final stored = firestore.store['doc-1']!;
    expect(stored.iosRef, isNotNull);
    expect(stored.outlookRef, isNotNull);
  });

  test('editing an already-linked event inside Butlu pushes an update, not a create',
      () async {
    firestore.store['doc-1'] = _event(
      id: 'doc-1',
      title: 'Rescheduled dinner',
      source: EventSource.butlu,
      lastModifiedBy: EventSource.butlu,
      lastModifiedAt: DateTime.utc(2026, 8, 30),
      iosRef: const ExternalRef(eventIdentifier: 'ios-1'),
      outlookRef: const ExternalRef(eventIdentifier: 'graph-1'),
    );

    await sync.runFullSync();

    expect(ios.createdEvents, isEmpty);
    expect(outlook.createdEvents, isEmpty);
    expect(ios.updatedEvents, hasLength(1));
    expect(outlook.updatedEvents, hasLength(1));
  });
}
