import '../models/calendar_event.dart';
import '../models/event_source.dart';

/// Shared-family event store. Backed by Firestore in Milestone 2
/// (`/families/{familyId}/events`); implemented here only as an interface so
/// the sync engine and its tests never depend on a live Firebase project.
abstract class FirestoreEventRepository {
  Stream<List<CalendarEvent>> watchEvents();

  Future<List<CalendarEvent>> fetchAll();

  Future<CalendarEvent?> findByExternalId({
    required EventSource source,
    required String externalId,
  });

  /// Creates or overwrites the event with the given id.
  Future<void> upsert(CalendarEvent event);

  Future<void> softDelete(String eventId);

  /// Bulk versions for the sync engine. Written as batches, so a sync of
  /// hundreds of events reaches [watchEvents] listeners as a handful of
  /// updates rather than one per event.
  Future<void> upsertAll(List<CalendarEvent> events);

  Future<void> softDeleteAll(List<String> eventIds);
}
