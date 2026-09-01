import '../models/calendar_event.dart';
import '../models/event_source.dart';
import 'external_calendar_repository.dart';

/// Microsoft Graph-backed calendar access. The real implementation
/// (Milestone 2) authenticates via `msal_auth` and calls
/// `/me/calendarView` (initial sync) and `/me/calendarView/delta`
/// (incremental sync). Kept as a bare interface here so the sync engine and
/// its tests never need a live Azure AD app registration.
abstract class OutlookCalendarRepository extends ExternalCalendarRepository {
  @override
  EventSource get source => EventSource.outlook;

  Future<bool> isSignedIn();

  Future<void> signIn();

  /// Cheap incremental pull using a delta link from a previous
  /// [fetchDeltaLink] call. Falls back to [fetchWindow] when no link exists
  /// yet (first sync).
  Future<({List<CalendarEvent> events, String nextDeltaLink})> fetchDelta(
    String deltaLink,
  );

  Future<String> fetchInitialDeltaLink(DateTime start, DateTime end);
}
