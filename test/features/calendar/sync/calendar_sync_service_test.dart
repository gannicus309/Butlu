import 'package:butlu/features/calendar/data/external_calendar_repository.dart';
import 'package:butlu/features/calendar/data/firestore_event_repository.dart';
import 'package:butlu/features/calendar/data/ios_calendar_repository.dart';
import 'package:butlu/features/calendar/data/outlook_calendar_repository.dart';
import 'package:butlu/features/calendar/models/calendar_event.dart';
import 'package:butlu/features/calendar/models/device_calendar_info.dart';
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
  Future<CalendarEvent?> findById(String id) async => store[id];

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

  bool permission = true;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => const [];

  @override
  String get ownerUid => 'uid-1';

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<void> signIn() async {}

  @override
  Future<({List<CalendarEvent> events, String nextDeltaLink})> fetchDelta(
    String deltaLink,
  ) async => (events: windowResult, nextDeltaLink: deltaLink);

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
  DateTime? start,
  String? calendarName,
}) {
  start ??= DateTime.utc(2026, 9, 1, 10);
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
    calendarName: calendarName,
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

  test(
    'an unchanged external pull is a no-op even when its timestamp is newer',
    () async {
      // Simulates device_calendar_plus, which stamps every iOS fetch with
      // "now" (no real last-modified field exists on that platform) -- a
      // newer timestamp alone must not be enough to trigger an overwrite.
      firestore.store['doc-1'] = _event(
        id: 'doc-1',
        title: 'Dentist',
        source: EventSource.ios,
        lastModifiedBy: EventSource.butlu,
        lastModifiedAt: DateTime.utc(2026, 8, 1),
        iosRef: const ExternalRef(eventIdentifier: 'ios-1'),
      );
      ios.windowResult = [
        _event(
          id: 'doc-1',
          title: 'Dentist',
          source: EventSource.ios,
          lastModifiedBy: EventSource.ios,
          lastModifiedAt: DateTime.utc(2026, 9, 1),
          iosRef: const ExternalRef(eventIdentifier: 'ios-1'),
        ),
      ];

      await sync.runFullSync();

      final stored = firestore.store['doc-1']!;
      expect(stored.lastModifiedBy, EventSource.butlu);
      expect(stored.lastModifiedAt, DateTime.utc(2026, 8, 1));
    },
  );

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

  test('an event just pulled from Outlook is not echoed back out to iOS in the same cycle', () async {
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
  });

  test(
    'a Butlu-native event is pushed out to both external calendars',
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
    },
  );

  test('editing an already-linked event inside Butlu pushes an update, not a create', () async {
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

  CalendarEvent iosImport(String id, String eventId, {DateTime? start}) =>
      _event(
        id: id,
        title: 'Swimming',
        source: EventSource.ios,
        lastModifiedBy: EventSource.ios,
        lastModifiedAt: DateTime.utc(2026, 9, 1),
        iosRef: ExternalRef(eventIdentifier: eventId),
        start: start,
      );

  test('each occurrence of a repeating iOS event gets its own entry', () async {
    ios.windowResult = [
      iosImport('swim@1', 'swim', start: DateTime.utc(2026, 9, 1, 17)),
      iosImport('swim@2', 'swim', start: DateTime.utc(2026, 9, 8, 17)),
      iosImport('swim@3', 'swim', start: DateTime.utc(2026, 9, 15, 17)),
    ];

    await sync.runFullSync();

    expect(
      firestore.store.keys,
      unorderedEquals(['swim@1', 'swim@2', 'swim@3']),
    );
  });

  test('an iOS event that disappears from the fetch is removed', () async {
    firestore.store['gone'] = iosImport('gone', 'ios-gone');
    firestore.store['kept'] = iosImport('kept', 'ios-kept');
    ios.windowResult = [iosImport('kept', 'ios-kept')];

    await sync.runFullSync();

    expect(firestore.store['gone']!.deleted, isTrue);
    expect(firestore.store['kept']!.deleted, isFalse);
  });

  test('nothing is removed when calendar access is not granted', () async {
    firestore.store['doc-1'] = iosImport('doc-1', 'ios-1');
    ios.permission = false;

    await sync.runFullSync();

    expect(firestore.store['doc-1']!.deleted, isFalse);
  });

  test(
    'another family member\'s imports are never removed by this phone',
    () async {
      firestore.store['theirs'] = CalendarEvent(
        id: 'theirs',
        title: 'Their event',
        startAt: DateTime.utc(2026, 9, 1, 10),
        endAt: DateTime.utc(2026, 9, 1, 11),
        timeZone: 'UTC',
        source: EventSource.ios,
        createdByUid: 'uid-2',
        iosRef: const ExternalRef(eventIdentifier: 'their-ios'),
        lastModifiedAt: DateTime.utc(2026, 9, 1),
        lastModifiedBy: EventSource.ios,
      );

      await sync.runFullSync();

      expect(firestore.store['theirs']!.deleted, isFalse);
    },
  );

  test('a removed iOS import comes back when it reappears', () async {
    firestore.store['doc-1'] = iosImport(
      'doc-1',
      'ios-1',
    ).copyWith(deleted: true);
    ios.windowResult = [iosImport('doc-1', 'ios-1')];

    await sync.runFullSync();

    expect(firestore.store['doc-1']!.deleted, isFalse);
  });

  test(
    'a Butlu event pushed to iOS is not taken over when it comes back',
    () async {
      firestore.store['doc-1'] = _event(
        id: 'doc-1',
        title: 'Family dinner',
        source: EventSource.butlu,
        lastModifiedBy: EventSource.butlu,
        lastModifiedAt: DateTime.utc(2026, 8, 30),
        iosRef: const ExternalRef(eventIdentifier: 'ios-1'),
      );
      ios.windowResult = [
        _event(
          id: 'ios-1',
          title: 'Family dinner',
          source: EventSource.ios,
          lastModifiedBy: EventSource.ios,
          lastModifiedAt: DateTime.utc(2026, 9, 1),
          iosRef: const ExternalRef(eventIdentifier: 'ios-1'),
          calendarName: 'Home',
        ),
      ];

      await sync.runFullSync();

      expect(firestore.store.keys, ['doc-1']);
      expect(firestore.store['doc-1']!.lastModifiedBy, EventSource.butlu);
    },
  );
}
