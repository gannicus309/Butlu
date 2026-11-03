import 'package:butlu/features/calendar/models/calendar_event.dart';
import 'package:butlu/features/calendar/models/day_layout.dart';
import 'package:butlu/features/calendar/models/event_source.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 11, 4);

CalendarEvent _e(
  String id,
  int startHour,
  int startMinute,
  int minutes, {
  bool allDay = false,
  DateTime? on,
}) {
  final base = on ?? _day;
  final start = DateTime(
    base.year,
    base.month,
    base.day,
    startHour,
    startMinute,
  ).toUtc();
  return CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: start.add(Duration(minutes: minutes)),
    isAllDay: allDay,
    timeZone: 'local',
    source: EventSource.ios,
    createdByUid: 'uid-1',
    lastModifiedAt: start,
    lastModifiedBy: EventSource.ios,
  );
}

TimelineSlot _slot(List<TimelineSlot> slots, String id) =>
    slots.singleWhere((s) => s.event.id == id);

void main() {
  test('events sit at their minutes from midnight', () {
    final slots = layoutDay([_e('a', 9, 30, 60)], _day);
    expect(slots.single.startMinute, 9 * 60 + 30);
    expect(slots.single.endMinute, 10 * 60 + 30);
    expect(slots.single.columns, 1);
  });

  test('overlapping events share the width side by side', () {
    final slots = layoutDay([_e('a', 9, 0, 60), _e('b', 9, 30, 60)], _day);
    expect(_slot(slots, 'a').columns, 2);
    expect(_slot(slots, 'a').column, isNot(_slot(slots, 'b').column));
  });

  test('back-to-back events do not overlap', () {
    final slots = layoutDay([_e('a', 9, 0, 60), _e('b', 10, 0, 60)], _day);
    expect(slots.every((s) => s.columns == 1), isTrue);
  });

  test('a freed column is reused within the same overlap group', () {
    // a 9-12 spans b 9-10 and c 10-11: c can take b's column.
    final slots = layoutDay([
      _e('a', 9, 0, 180),
      _e('b', 9, 0, 60),
      _e('c', 10, 0, 60),
    ], _day);
    expect(_slot(slots, 'a').columns, 2);
    expect(_slot(slots, 'c').column, _slot(slots, 'b').column);
  });

  test('an event running past midnight is clipped to the day', () {
    final slots = layoutDay([_e('late', 23, 0, 120)], _day);
    expect(slots.single.endMinute, 24 * 60);
    final next = layoutDay([
      _e('late', 23, 0, 120),
    ], _day.add(const Duration(days: 1)));
    expect(next.single.startMinute, 0);
    expect(next.single.endMinute, 60);
  });

  test('all-day events are left out of the timeline', () {
    expect(layoutDay([_e('hol', 0, 0, 24 * 60, allDay: true)], _day), isEmpty);
  });

  test('very short events still get a tappable block', () {
    final slots = layoutDay([_e('quick', 9, 0, 5)], _day);
    expect(slots.single.endMinute - slots.single.startMinute, 20);
  });
}
