import 'calendar_category.dart';
import 'event_source.dart';

/// Reference to the same event in an external calendar system (EventKit or
/// Microsoft Graph), used to dedupe on ingest and to push updates back out.
class ExternalRef {
  final String eventIdentifier;
  final String? calendarId;
  final String? changeKey; // Outlook only, absent for iOS.

  const ExternalRef({
    required this.eventIdentifier,
    this.calendarId,
    this.changeKey,
  });

  Map<String, dynamic> toJson() => {
    'eventIdentifier': eventIdentifier,
    'calendarId': calendarId,
    'changeKey': changeKey,
  };

  factory ExternalRef.fromJson(Map<String, dynamic> json) => ExternalRef(
    eventIdentifier: json['eventIdentifier'] as String,
    calendarId: json['calendarId'] as String?,
    changeKey: json['changeKey'] as String?,
  );
}

/// Unified event model shared by the Firestore store and both external
/// calendar repositories. Mirrors the /families/{id}/events/{eventId} schema.
class CalendarEvent {
  final String id;
  final String title;
  final String notes;
  final DateTime startAt; // UTC instant.
  final DateTime endAt; // UTC instant.
  final bool isAllDay;
  final String timeZone; // IANA name captured at creation/edit time.
  final EventSource source;
  final String createdByUid;
  final String? originDeviceId;
  final ExternalRef? iosRef;
  final ExternalRef? outlookRef;

  /// Name and `#RRGGBB` colour of the phone calendar an iOS event came from
  /// (e.g. a spouse's shared iCloud calendar), so the UI can show whose event
  /// it is. Null for Butlu-native and Outlook events.
  final String? calendarName;
  final String? colorHex;

  /// Set on iOS imports from the picker's role for their calendar; use
  /// [effectiveCategory] to read it, which also covers the other sources.
  final CalendarCategory? category;
  final DateTime lastModifiedAt;
  final EventSource lastModifiedBy;
  final bool deleted;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.notes = '',
    required this.startAt,
    required this.endAt,
    this.isAllDay = false,
    required this.timeZone,
    required this.source,
    required this.createdByUid,
    this.originDeviceId,
    this.iosRef,
    this.outlookRef,
    this.calendarName,
    this.colorHex,
    this.category,
    required this.lastModifiedAt,
    required this.lastModifiedBy,
    this.deleted = false,
  });

  /// Decides the event's colour: the picker role for iOS imports (Family
  /// until one is set), green for Butlu-native events, blue for Outlook.
  CalendarCategory get effectiveCategory {
    final explicit = category;
    if (explicit != null) return explicit;
    switch (source) {
      case EventSource.butlu:
        return CalendarCategory.butlu;
      case EventSource.outlook:
        return CalendarCategory.myOffice;
      case EventSource.ios:
        return CalendarCategory.family;
    }
  }

  ExternalRef? refFor(EventSource externalSource) {
    switch (externalSource) {
      case EventSource.ios:
        return iosRef;
      case EventSource.outlook:
        return outlookRef;
      case EventSource.butlu:
        return null;
    }
  }

  CalendarEvent copyWith({
    String? title,
    String? notes,
    DateTime? startAt,
    DateTime? endAt,
    bool? isAllDay,
    String? timeZone,
    EventSource? source,
    ExternalRef? iosRef,
    ExternalRef? outlookRef,
    String? calendarName,
    String? colorHex,
    CalendarCategory? category,
    DateTime? lastModifiedAt,
    EventSource? lastModifiedBy,
    bool? deleted,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isAllDay: isAllDay ?? this.isAllDay,
      timeZone: timeZone ?? this.timeZone,
      source: source ?? this.source,
      createdByUid: createdByUid,
      originDeviceId: originDeviceId,
      iosRef: iosRef ?? this.iosRef,
      outlookRef: outlookRef ?? this.outlookRef,
      calendarName: calendarName ?? this.calendarName,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      deleted: deleted ?? this.deleted,
    );
  }
}
