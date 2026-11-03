import 'package:device_calendar_plus/device_calendar_plus.dart' as dcp;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../models/calendar_event.dart';
import '../models/device_calendar_info.dart';
import '../models/event_source.dart';
import 'ios_calendar_repository.dart';

/// Real EventKit-backed implementation via `device_calendar_plus`.
///
/// `device_calendar_plus`'s `Event` has no last-modified timestamp (EventKit
/// exposes one, but the plugin doesn't surface it), so every fetched event is
/// stamped with the current sync time rather than a real edit time. The sync
/// engine's content-equality short-circuit (see `CalendarSyncService`) is
/// what keeps that from stomping pending Firestore-side edits on every sync;
/// it does not fully cover both sides editing the same event between two
/// syncs -- a known, accepted limitation, not a bug to chase here.
///
/// The plugin only supports Android/iOS -- calling into it on any other
/// target (web, Windows, ...) throws a raw "platform not initialized" error,
/// which is what's being guarded against below. That's expected on those
/// platforms, not a bug; it's how we're testing everything short of the
/// actual EventKit calls until there's a real device/simulator.
class IosCalendarRepositoryImpl extends IosCalendarRepository {
  IosCalendarRepositoryImpl({
    required this._currentUid,
    this.excludedCalendarIds,
    dcp.DeviceCalendar? plugin,
  }) : _plugin = plugin ?? dcp.DeviceCalendar.instance;

  final String _currentUid;
  final dcp.DeviceCalendar _plugin;

  /// Calendars the user switched off in the picker. Null until they've
  /// touched it, in which case [DeviceCalendarInfo.isExcludedByDefault]
  /// decides instead.
  final Set<String>? excludedCalendarIds;

  @override
  String get ownerUid => _currentUid;

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool _isUsable(dcp.CalendarPermissionStatus status) =>
      status == dcp.CalendarPermissionStatus.granted ||
      status == dcp.CalendarPermissionStatus.writeOnly;

  @override
  Future<bool> hasPermission() async {
    if (!_isSupportedPlatform) return false;
    return _isUsable(await _plugin.hasPermissions());
  }

  @override
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;
    return _isUsable(await _plugin.requestPermissions());
  }

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async {
    if (!await hasPermission()) return const [];
    final calendars = await _plugin.listCalendars();
    return [
      for (final c in calendars)
        DeviceCalendarInfo(
          id: c.id,
          name: c.name,
          colorHex: c.colorHex,
          accountName: c.accountName,
          readOnly: c.readOnly,
        ),
    ];
  }

  @override
  Future<List<CalendarEvent>> fetchWindow(DateTime start, DateTime end) async {
    if (!await hasPermission()) return const [];
    final excluded = excludedCalendarIds;
    final included = {
      for (final c in await listCalendars())
        if (excluded == null
            ? !c.isExcludedByDefault
            : !excluded.contains(c.id))
          c.id: c,
    };
    // An empty `calendarIds` list would mean "all calendars" to the plugin,
    // the opposite of what everything-switched-off should do.
    if (included.isEmpty) return const [];
    final events = await _plugin.listEvents(
      start,
      end,
      calendarIds: included.keys.toList(),
    );
    final syncedAt = DateTime.now().toUtc();
    return events
        .map(
          (e) => _toCalendarEvent(
            e,
            calendar: included[e.calendarId],
            syncedAt: syncedAt,
          ),
        )
        .toList();
  }

  @override
  Future<ExternalRef> createEvent(CalendarEvent event) async {
    _requireSupportedPlatform();
    final eventId = await _plugin.createEvent(
      title: event.title,
      startDate: event.startAt.toLocal(),
      endDate: event.endAt.toLocal(),
      isAllDay: event.isAllDay,
      description: event.notes.isEmpty ? null : event.notes,
    );
    return ExternalRef(eventIdentifier: eventId);
  }

  @override
  Future<void> updateEvent(ExternalRef ref, CalendarEvent event) async {
    _requireSupportedPlatform();
    await _plugin.updateEvent(
      eventId: ref.eventIdentifier,
      title: event.title,
      startDate: event.startAt.toLocal(),
      endDate: event.endAt.toLocal(),
      isAllDay: event.isAllDay,
      description: dcp.Patch.set(event.notes),
    );
  }

  @override
  Future<void> deleteEvent(ExternalRef ref) async {
    _requireSupportedPlatform();
    await _plugin.deleteEvent(eventId: ref.eventIdentifier);
  }

  void _requireSupportedPlatform() {
    if (!_isSupportedPlatform) {
      throw UnsupportedError(
        "iOS Calendar sync isn't available on this platform (needs a real "
        'iOS or Android device/simulator).',
      );
    }
  }

  /// Every occurrence of a repeating event shares one EventKit `eventId`, so
  /// keying on that alone collapsed a weekly event into a single entry.
  /// Occurrences are told apart by start time instead (the plugin's own
  /// `instanceId` is documented as unstable). One-off events keep the bare
  /// `eventId`, matching documents synced before this distinction existed.
  static String firestoreIdFor(dcp.Event event) => event.isRecurring
      ? '${event.eventId}@${event.startDate.toUtc().millisecondsSinceEpoch}'
      : event.eventId;

  CalendarEvent _toCalendarEvent(
    dcp.Event event, {
    required DeviceCalendarInfo? calendar,
    required DateTime syncedAt,
  }) {
    return CalendarEvent(
      id: firestoreIdFor(event),
      title: event.title,
      notes: event.description ?? '',
      startAt: event.startDate.toUtc(),
      endAt: event.endDate.toUtc(),
      isAllDay: event.isAllDay,
      timeZone: event.timeZone ?? 'local',
      source: EventSource.ios,
      createdByUid: _currentUid,
      iosRef: ExternalRef(
        eventIdentifier: event.eventId,
        calendarId: event.calendarId,
      ),
      calendarName: calendar?.name,
      colorHex: event.colorHex ?? calendar?.colorHex,
      lastModifiedAt: syncedAt,
      lastModifiedBy: EventSource.ios,
    );
  }
}
