import 'calendar_event.dart';

/// Where a timed event sits in a one-day timeline: minutes from local
/// midnight, clamped to that day, and which side-by-side column it takes
/// among the events it overlaps.
class TimelineSlot {
  const TimelineSlot({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    required this.column,
    required this.columns,
  });

  final CalendarEvent event;
  final int startMinute;
  final int endMinute;
  final int column;

  /// How many columns its overlap group is split into.
  final int columns;
}

/// Events shorter than this still get a block tall enough to tap and read.
const _minDurationMinutes = 20;

/// Lays out [day]'s timed events Outlook-style: overlapping events share the
/// width in columns; events that only touch end-to-start don't overlap.
/// Events running past midnight are clipped to [day]. All-day events are
/// left out -- they go in their own strip above the timeline.
List<TimelineSlot> layoutDay(List<CalendarEvent> events, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final items = <({CalendarEvent event, int start, int end})>[];
  for (final e in events) {
    if (e.isAllDay) continue;
    final start = e.startAt.toLocal();
    final end = e.endAt.toLocal();
    if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) continue;
    final s = start.isBefore(dayStart)
        ? 0
        : start.difference(dayStart).inMinutes;
    var en = end.isAfter(dayEnd) ? 24 * 60 : end.difference(dayStart).inMinutes;
    if (en - s < _minDurationMinutes) {
      en = (s + _minDurationMinutes).clamp(0, 24 * 60);
    }
    items.add((event: e, start: s, end: en));
  }
  items.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : b.end.compareTo(a.end);
  });

  final result = <TimelineSlot>[];
  // Walk overlap groups: a group ends once no event in it reaches the next
  // event's start. Within a group, each event takes the first free column.
  var group = <({CalendarEvent event, int start, int end, int column})>[];
  var groupEnd = -1;

  void flush() {
    if (group.isEmpty) return;
    final columns =
        group.map((g) => g.column).reduce((a, b) => a > b ? a : b) + 1;
    for (final g in group) {
      result.add(
        TimelineSlot(
          event: g.event,
          startMinute: g.start,
          endMinute: g.end,
          column: g.column,
          columns: columns,
        ),
      );
    }
    group = [];
    groupEnd = -1;
  }

  for (final item in items) {
    if (item.start >= groupEnd) flush();
    final columnEnds = <int, int>{};
    for (final g in group) {
      final current = columnEnds[g.column];
      if (current == null || g.end > current) columnEnds[g.column] = g.end;
    }
    var column = 0;
    while ((columnEnds[column] ?? -1) > item.start) {
      column++;
    }
    group.add((
      event: item.event,
      start: item.start,
      end: item.end,
      column: column,
    ));
    if (item.end > groupEnd) groupEnd = item.end;
  }
  flush();
  return result;
}
