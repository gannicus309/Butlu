import 'calendar_category.dart';
import 'calendar_event.dart';

/// Two events that overlap in a way worth warning about.
class EventConflict {
  const EventConflict(this.a, this.b);

  /// [a] starts no later than [b].
  final CalendarEvent a;
  final CalendarEvent b;

  /// Stable id for "already notified about this one", independent of the
  /// order the pair was found in. Includes both start times, so a clash
  /// that's moved to a new time counts as new.
  String get key {
    final ids = [
      '${a.id}@${a.startAt.millisecondsSinceEpoch}',
      '${b.id}@${b.startAt.millisecondsSinceEpoch}',
    ]..sort();
    return ids.join('|');
  }
}

bool _overlaps(CalendarEvent a, CalendarEvent b) =>
    a.startAt.isBefore(b.endAt) && b.startAt.isBefore(a.endAt);

/// Whether two overlapping events are a real clash rather than ordinary
/// noise: they're from different colour groups (your office vs your wife's
/// office, family vs either office, ...), or one was added in Butlu itself.
/// Two meetings in the same office calendar overlapping is left alone --
/// that's the office calendar's business.
bool isClash(CalendarEvent a, CalendarEvent b) {
  if (a.isAllDay || b.isAllDay) return false;
  if (!_overlaps(a, b)) return false;
  final ca = a.effectiveCategory;
  final cb = b.effectiveCategory;
  return ca != cb || ca == CalendarCategory.butlu;
}

/// Every clash among [events] starting in [from, to). [events] should
/// already be de-duplicated (see `mergeDuplicates`), or a meeting mirrored
/// into two calendars would clash with itself.
List<EventConflict> findConflicts(
  Iterable<CalendarEvent> events, {
  required DateTime from,
  required DateTime to,
}) {
  final timed = [
    for (final e in events)
      if (!e.deleted &&
          !e.isAllDay &&
          e.endAt.isAfter(from) &&
          e.startAt.isBefore(to))
        e,
  ]..sort((x, y) => x.startAt.compareTo(y.startAt));

  final result = <EventConflict>[];
  for (var i = 0; i < timed.length; i++) {
    for (var j = i + 1; j < timed.length; j++) {
      // Sorted by start: once j starts after i ends, nothing later overlaps.
      if (!timed[j].startAt.isBefore(timed[i].endAt)) break;
      if (isClash(timed[i], timed[j])) {
        result.add(EventConflict(timed[i], timed[j]));
      }
    }
  }
  return result;
}

/// Existing events that a new event from [start] to [end] would overlap --
/// for warning before it's saved. Any overlap counts for a new event.
List<CalendarEvent> clashesForNewEvent(
  Iterable<CalendarEvent> existing,
  DateTime start,
  DateTime end,
) => [
  for (final e in existing)
    if (!e.deleted &&
        !e.isAllDay &&
        e.startAt.isBefore(end) &&
        start.isBefore(e.endAt))
      e,
];
