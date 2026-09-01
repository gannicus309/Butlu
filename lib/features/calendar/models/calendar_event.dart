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
    required this.lastModifiedAt,
    required this.lastModifiedBy,
    this.deleted = false,
  });

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
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      deleted: deleted ?? this.deleted,
    );
  }
}
