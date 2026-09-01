import '../models/calendar_event.dart';
import '../models/event_source.dart';

/// Common interface for the two external calendars Butlu syncs with. iOS
/// (EventKit) and Outlook (Microsoft Graph) implement this identically for
/// the sync engine's purposes; source-specific extras (e.g. Outlook's delta
/// link) live on the subtype interfaces in their own files.
abstract class ExternalCalendarRepository {
  EventSource get source;

  /// Full pull of events in [start, end). Used for the initial sync and as
  /// the iOS fallback (EventKit has no delta-query concept).
  Future<List<CalendarEvent>> fetchWindow(DateTime start, DateTime end);

  /// Creates the event natively and returns the reference to link back into
  /// the Firestore doc.
  Future<ExternalRef> createEvent(CalendarEvent event);

  Future<void> updateEvent(ExternalRef ref, CalendarEvent event);

  Future<void> deleteEvent(ExternalRef ref);
}
