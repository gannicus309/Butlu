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

  Future<void> runFullSync() async {
    final start = _now().subtract(_windowPast);
    final end = _now().add(_windowFuture);

    final iosAllowed = await ios.hasPermission();
    final iosEvents = await ios.fetchWindow(start, end);
    final outlookEvents = await outlook?.fetchWindow(start, end) ?? const [];

    final seenIosDocIds = <String>{};
    for (final event in [...iosEvents, ...outlookEvents]) {
      final docId = await _ingestExternalEvent(event);
      if (docId != null && event.source == EventSource.ios) {
        seenIosDocIds.add(docId);
      }
    }

    // Without permission the fetch is empty by necessity, not because the
    // user deleted everything -- cleaning up then would wipe their calendar.
    if (iosAllowed) {
      await _removeVanishedIosImports(seenIosDocIds, start, end);
    }

    await _pushPendingButluChanges();
  }

  /// Ingests one externally fetched event and returns the id of the Firestore
  /// document it now corresponds to (null if it was malformed).
  Future<String?> _ingestExternalEvent(CalendarEvent incoming) async {
    final externalId = incoming.refFor(incoming.source)?.eventIdentifier;
    if (externalId == null) return null; // Malformed fetch result; ignore.

    final existing = await _findExisting(incoming, externalId);

    if (existing == null) {
      await firestore.upsert(incoming);
      return incoming.id;
    }

    if (existing.deleted) {
      // An iOS import that was cleaned up -- its calendar switched off, say --
      // is back in the fetch, so restore it. A Butlu event deleted inside
      // Butlu stays deleted even though its pushed iOS copy still exists.
      if (existing.source == EventSource.ios) await firestore.upsert(incoming);
      return existing.id;
    }

    await _mergeInto(existing, incoming);
    return existing.id;
  }

  Future<CalendarEvent?> _findExisting(
    CalendarEvent incoming,
    String externalId,
  ) async {
    final byId = await firestore.findById(incoming.id);
    if (byId != null) return byId;
    final byExternalId = await firestore.findByExternalId(
      source: incoming.source,
      externalId: externalId,
    );
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
  Future<void> _removeVanishedIosImports(
    Set<String> seen,
    DateTime start,
    DateTime end,
  ) async {
    for (final event in await firestore.fetchAll()) {
      if (event.deleted ||
          event.source != EventSource.ios ||
          event.lastModifiedBy != EventSource.ios ||
          event.createdByUid != ios.ownerUid ||
          event.startAt.isBefore(start) ||
          !event.startAt.isBefore(end) ||
          seen.contains(event.id)) {
        continue;
      }
      await firestore.softDelete(event.id);
    }
  }

  Future<void> _mergeInto(
    CalendarEvent existing,
    CalendarEvent incoming,
  ) async {
    // EventKit (via device_calendar_plus) exposes no last-modified timestamp,
    // so the iOS repository stamps every fetch with the current sync time --
    // meaning "is incoming newer" is nearly always true for iOS and would
    // stomp a pending Firestore-side edit on every single sync otherwise.
    // Skipping when the content hasn't actually changed sidesteps that for
    // the common case (nothing changed since last sync); it does not fully
    // solve the rarer case of both sides editing the same event between two
    // syncs, which is a real, documented limitation of the plugin, not of
    // this engine.
    if (_hasSameContent(incoming, existing)) return;

    if (!incoming.lastModifiedAt.isAfter(existing.lastModifiedAt)) {
      // Firestore's copy is newer -- a local edit (via Butlu, or the other
      // external source) hasn't been pushed out yet. Leave it; the push
      // step below is what reconciles that.
      return;
    }

    // External edit is newer than what we have. Absorb it, but never drop
    // the *other* source's link -- an Outlook update must not erase the iOS
    // ref, and vice versa.
    final merged = existing.copyWith(
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
      lastModifiedAt: incoming.lastModifiedAt,
      lastModifiedBy: incoming.source,
    );
    await firestore.upsert(merged);
  }

  /// [a] is the incoming external copy, [b] the stored one.
  bool _hasSameContent(CalendarEvent a, CalendarEvent b) {
    return a.title == b.title &&
        a.notes == b.notes &&
        a.startAt == b.startAt &&
        a.endAt == b.endAt &&
        a.isAllDay == b.isAllDay &&
        a.timeZone == b.timeZone &&
        // Which calendar an event sits in only matters for iOS imports; a
        // Butlu event pushed into iOS coming back tagged with the default
        // calendar's name is not an edit.
        (b.source != EventSource.ios ||
            (a.calendarName == b.calendarName && a.colorHex == b.colorHex));
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
