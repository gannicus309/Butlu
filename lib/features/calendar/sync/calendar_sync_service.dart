import '../data/external_calendar_repository.dart';
import '../data/firestore_event_repository.dart';
import '../data/ios_calendar_repository.dart';
import '../data/outlook_calendar_repository.dart';
import '../models/calendar_event.dart';
import '../models/event_source.dart';

/// Merges iOS Calendar (EventKit) and Outlook (Microsoft Graph) into the
/// shared Firestore event store, and pushes Butlu-originated changes back
/// out to both. Has zero Flutter/widget dependencies -- it only talks to the
/// three repository interfaces, so it is unit-testable with fakes and reusable
/// later from a Cloud Function if client-only sync is outgrown.
///
/// Echo-loop avoidance: the push step only ever considers events whose most
/// recent edit is recorded as [EventSource.butlu] (`lastModifiedBy`) --
/// either a genuinely Butlu-native event, or an external event that was
/// subsequently edited inside Butlu's own UI. [_ingestExternalEvent] always
/// stamps `lastModifiedBy` with the *external* source it just absorbed, so an
/// event that was only just pulled in this same cycle is never eligible to be
/// pushed straight back out in that same cycle.
class CalendarSyncService {
  final FirestoreEventRepository firestore;
  final IosCalendarRepository ios;
  final OutlookCalendarRepository? outlook;
  final DateTime Function() _now;

  /// [outlook] is nullable: direct Microsoft Graph access needs an Azure AD
  /// app registration, which isn't available on every tenant (e.g. a
  /// corporate-managed Microsoft 365 account may block self-service app
  /// registration). When null, Outlook simply isn't a sync target -- a user
  /// can still get their Outlook events into Butlu by adding their account as
  /// a native iOS Exchange calendar, which then arrives through [ios] like
  /// any other EventKit calendar.
  CalendarSyncService({
    required this.firestore,
    required this.ios,
    this.outlook,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _windowPast = Duration(days: 90);
  static const _windowFuture = Duration(days: 365);

  /// Returns how many iOS events came from each phone calendar, so the
  /// picker can show the user what was actually imported.
  Future<Map<String, int>> runFullSync() async {
    final start = _now().subtract(_windowPast);
    final end = _now().add(_windowFuture);

    final iosAllowed = await ios.hasPermission();
    final iosEvents = await ios.fetchWindow(start, end);
    final outlookEvents = await outlook?.fetchWindow(start, end) ?? const [];

    // One read of everything stored, matched against in memory, with the
    // writes sent as batches. Per-event round trips made a sync of a few
    // dozen events take ~25s; per-event (even parallel) writes made the live
    // event listener re-send the whole collection once per write, which with
    // a ~1,200-event Outlook calendar ran the app out of memory.
    final stored = _StoredIndex(await firestore.fetchAll());
    final writes = <CalendarEvent>[];
    final seenIosDocIds = <String>{};
    for (final event in [...iosEvents, ...outlookEvents]) {
      final docId = _ingestExternalEvent(event, stored, writes);
      if (docId != null && event.source == EventSource.ios) {
        seenIosDocIds.add(docId);
      }
    }
    await firestore.upsertAll(writes);

    // Without permission the fetch is empty by necessity, not because the
    // user deleted everything -- cleaning up then would wipe their calendar.
    if (iosAllowed) {
      await _removeVanishedIosImports(stored, seenIosDocIds, start, end);
    }

    await _pushPendingButluChanges();

    final perCalendar = <String, int>{};
    for (final event in iosEvents) {
      final calendarId = event.iosRef?.calendarId;
      if (calendarId != null) {
        perCalendar[calendarId] = (perCalendar[calendarId] ?? 0) + 1;
      }
    }
    return perCalendar;
  }

  /// Ingests one externally fetched event, queueing any write onto [writes],
  /// and returns the id of the Firestore document it now corresponds to
  /// (null if it was malformed).
  String? _ingestExternalEvent(
    CalendarEvent incoming,
    _StoredIndex stored,
    List<CalendarEvent> writes,
  ) {
    final externalId = incoming.refFor(incoming.source)?.eventIdentifier;
    if (externalId == null) return null; // Malformed fetch result; ignore.

    final existing = _findExisting(incoming, externalId, stored);

    if (existing == null) {
      writes.add(incoming);
      stored.add(incoming);
      return incoming.id;
    }

    if (existing.deleted) {
      // An iOS import that was cleaned up -- its calendar switched off, say --
      // is back in the fetch, so restore it. A Butlu event deleted inside
      // Butlu stays deleted even though its pushed iOS copy still exists.
      if (existing.source == EventSource.ios) {
        writes.add(incoming);
      }
      return existing.id;
    }

    final merged = _merged(existing, incoming);
    if (merged != null) writes.add(merged);
    return existing.id;
  }

  CalendarEvent? _findExisting(
    CalendarEvent incoming,
    String externalId,
    _StoredIndex stored,
  ) {
    final byId = stored.byId[incoming.id];
    if (byId != null) return byId;
    final byExternalId = stored.byExternalId[(incoming.source, externalId)];
    // For iOS, every occurrence of a repeating event shares one external id,
    // so an external-id match is only trusted for a Butlu event this engine
    // pushed out itself (those are never recurring); imported iOS events are
    // always found by their per-occurrence document id above.
    if (incoming.source == EventSource.ios &&
        byExternalId?.source != EventSource.butlu) {
      return null;
    }
    return byExternalId;
  }

  /// Soft-deletes events this phone imported from iOS that no longer come
  /// back in the fetch: deleted or moved in iOS Calendar, or from a calendar
  /// the user has since switched off. Only this phone's own imports, inside
  /// the sync window, that haven't been edited in Butlu since.
  ///
  /// Judged against [stored] (what Firestore held when this sync started)
  /// rather than a fresh read: anything written during the sync was seen,
  /// so it's never a candidate anyway.
  Future<void> _removeVanishedIosImports(
    _StoredIndex stored,
    Set<String> seen,
    DateTime start,
    DateTime end,
  ) async {
    await firestore.softDeleteAll([
      for (final event in stored.byId.values)
        if (!event.deleted &&
            event.source == EventSource.ios &&
            event.lastModifiedBy == EventSource.ios &&
            event.createdByUid == ios.ownerUid &&
            !event.startAt.isBefore(start) &&
            event.startAt.isBefore(end) &&
            !seen.contains(event.id))
          event.id,
    ]);
  }

  /// The stored event updated with an external edit, or null when there's
  /// nothing to write.
  CalendarEvent? _merged(CalendarEvent existing, CalendarEvent incoming) {
    // EventKit (via device_calendar_plus) exposes no last-modified timestamp,
    // so the iOS repository stamps every fetch with the current sync time --
    // meaning "is incoming newer" is nearly always true for iOS and would
    // stomp a pending Firestore-side edit on every single sync otherwise.
    // Skipping when the content hasn't actually changed sidesteps that for
    // the common case (nothing changed since last sync); it does not fully
    // solve the rarer case of both sides editing the same event between two
    // syncs, which is a real, documented limitation of the plugin, not of
    // this engine.
    if (_hasSameContent(incoming, existing)) return null;

    if (!incoming.lastModifiedAt.isAfter(existing.lastModifiedAt)) {
      // Firestore's copy is newer -- a local edit (via Butlu, or the other
      // external source) hasn't been pushed out yet. Leave it; the push
      // step below is what reconciles that.
      return null;
    }

    // External edit is newer than what we have. Absorb it, but never drop
    // the *other* source's link -- an Outlook update must not erase the iOS
    // ref, and vice versa.
    return existing.copyWith(
      title: incoming.title,
      notes: incoming.notes,
      startAt: incoming.startAt,
      endAt: incoming.endAt,
      isAllDay: incoming.isAllDay,
      timeZone: incoming.timeZone,
      iosRef: incoming.source == EventSource.ios
          ? incoming.iosRef
          : existing.iosRef,
      outlookRef: incoming.source == EventSource.outlook
          ? incoming.outlookRef
          : existing.outlookRef,
      calendarName: existing.source == EventSource.ios
          ? incoming.calendarName
          : existing.calendarName,
      colorHex: existing.source == EventSource.ios
          ? incoming.colorHex
          : existing.colorHex,
      category: existing.source == EventSource.ios
          ? incoming.category
          : existing.category,
      lastModifiedAt: incoming.lastModifiedAt,
      lastModifiedBy: incoming.source,
    );
  }

  /// [a] is the incoming external copy, [b] the stored one.
  bool _hasSameContent(CalendarEvent a, CalendarEvent b) {
    return a.title == b.title &&
        a.notes == b.notes &&
        // Same instant, whatever the representation: Firestore hands dates
        // back in local time and EventKit in UTC, and `==` on DateTime
        // treats those as different.
        a.startAt.isAtSameMomentAs(b.startAt) &&
        a.endAt.isAtSameMomentAs(b.endAt) &&
        a.isAllDay == b.isAllDay &&
        a.timeZone == b.timeZone &&
        // Which calendar an event sits in only matters for iOS imports; a
        // Butlu event pushed into iOS coming back tagged with the default
        // calendar's name is not an edit.
        (b.source != EventSource.ios ||
            (a.calendarName == b.calendarName &&
                a.colorHex == b.colorHex &&
                a.category == b.category));
  }

  Future<void> _pushPendingButluChanges() async {
    final all = await firestore.fetchAll();
    for (final event in all) {
      if (event.deleted || event.lastModifiedBy != EventSource.butlu) {
        continue;
      }

      var updated = event;
      updated = await _pushToTarget(updated, ios, updated.iosRef);
      final outlookTarget = outlook;
      if (outlookTarget != null) {
        updated = await _pushToTarget(
          updated,
          outlookTarget,
          updated.outlookRef,
        );
      }
      if (!identical(updated, event)) {
        await firestore.upsert(updated);
      }
    }
  }

  Future<CalendarEvent> _pushToTarget(
    CalendarEvent event,
    ExternalCalendarRepository target,
    ExternalRef? existingRef,
  ) async {
    if (existingRef == null) {
      final ref = await target.createEvent(event);
      return event.copyWith(
        iosRef: target.source == EventSource.ios ? ref : event.iosRef,
        outlookRef: target.source == EventSource.outlook
            ? ref
            : event.outlookRef,
      );
    }
    await target.updateEvent(existingRef, event);
    return event;
  }
}

/// Everything stored in Firestore at the start of a sync, looked up by
/// document id and by external (iOS/Outlook) id.
class _StoredIndex {
  _StoredIndex(List<CalendarEvent> events) {
    events.forEach(add);
  }

  final byId = <String, CalendarEvent>{};
  final byExternalId = <(EventSource, String), CalendarEvent>{};

  void add(CalendarEvent event) {
    byId[event.id] = event;
    for (final source in const [EventSource.ios, EventSource.outlook]) {
      final ref = event.refFor(source);
      if (ref != null) {
        byExternalId.putIfAbsent((source, ref.eventIdentifier), () => event);
      }
    }
  }
}
