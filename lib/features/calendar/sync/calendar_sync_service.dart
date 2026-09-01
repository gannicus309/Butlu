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
  final OutlookCalendarRepository outlook;
  final DateTime Function() _now;

  CalendarSyncService({
    required this.firestore,
    required this.ios,
    required this.outlook,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _windowPast = Duration(days: 90);
  static const _windowFuture = Duration(days: 365);

  Future<void> runFullSync() async {
    final start = _now().subtract(_windowPast);
    final end = _now().add(_windowFuture);

    final iosEvents = await ios.fetchWindow(start, end);
    final outlookEvents = await outlook.fetchWindow(start, end);

    for (final event in [...iosEvents, ...outlookEvents]) {
      await _ingestExternalEvent(event);
    }

    await _pushPendingButluChanges();
  }

  Future<void> _ingestExternalEvent(CalendarEvent incoming) async {
    final externalId = incoming.refFor(incoming.source)?.eventIdentifier;
    if (externalId == null) return; // Malformed fetch result; ignore.

    final existing = await firestore.findByExternalId(
      source: incoming.source,
      externalId: externalId,
    );

    if (existing == null) {
      await firestore.upsert(incoming);
      return;
    }

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
      iosRef:
          incoming.source == EventSource.ios ? incoming.iosRef : existing.iosRef,
      outlookRef: incoming.source == EventSource.outlook
          ? incoming.outlookRef
          : existing.outlookRef,
      lastModifiedAt: incoming.lastModifiedAt,
      lastModifiedBy: incoming.source,
    );
    await firestore.upsert(merged);
  }

  Future<void> _pushPendingButluChanges() async {
    final all = await firestore.fetchAll();
    for (final event in all) {
      if (event.deleted || event.lastModifiedBy != EventSource.butlu) {
        continue;
      }

      var updated = event;
      updated = await _pushToTarget(updated, ios, updated.iosRef);
      updated = await _pushToTarget(updated, outlook, updated.outlookRef);
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
        outlookRef:
            target.source == EventSource.outlook ? ref : event.outlookRef,
      );
    }
    await target.updateEvent(existingRef, event);
    return event;
  }
}
