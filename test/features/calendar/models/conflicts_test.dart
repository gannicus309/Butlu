import 'package:butlu/features/calendar/models/calendar_category.dart';
import 'package:butlu/features/calendar/models/calendar_event.dart';
import 'package:butlu/features/calendar/models/conflicts.dart';
import 'package:butlu/features/calendar/models/event_source.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _e(
  String id,
  int hour,
  int minutes,
  CalendarCategory category, {
  bool allDay = false,
}) {
  final start = DateTime.utc(2026, 11, 10, hour);
  return CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: start.add(Duration(minutes: minutes)),
    isAllDay: allDay,
    timeZone: 'UTC',
    source: category == CalendarCategory.butlu
        ? EventSource.butlu
        : EventSource.ios,
    createdByUid: 'uid-1',
    category: category,
    lastModifiedAt: start,
    lastModifiedBy: EventSource.ios,
  );
}

final _from = DateTime.utc(2026, 11, 1);
final _to = DateTime.utc(2026, 12, 1);

void main() {
  test('my office vs wife\'s office at the same time is a clash', () {
    final conflicts = findConflicts(
      [
        _e('mine', 9, 60, CalendarCategory.myOffice),
        _e('hers', 9, 30, CalendarCategory.partnerOffice),
      ],
      from: _from,
      to: _to,
    );
    expect(conflicts.single.key, contains('mine'));
  });

  test('two meetings in the same office calendar are not a clash', () {
    final conflicts = findConflicts(
      [
        _e('a', 9, 60, CalendarCategory.myOffice),
        _e('b', 9, 60, CalendarCategory.myOffice),
      ],
      from: _from,
      to: _to,
    );
    expect(conflicts, isEmpty);
  });

  test('two events added in Butlu that overlap are a clash', () {
    final conflicts = findConflicts(
      [
        _e('a', 18, 60, CalendarCategory.butlu),
        _e('b', 18, 30, CalendarCategory.butlu),
      ],
      from: _from,
      to: _to,
    );
    expect(conflicts, hasLength(1));
  });

  test('back-to-back events and all-day events never clash', () {
    final conflicts = findConflicts(
      [
        _e('a', 9, 60, CalendarCategory.myOffice),
        _e('b', 10, 60, CalendarCategory.family),
        _e('holiday', 0, 24 * 60, CalendarCategory.family, allDay: true),
      ],
      from: _from,
      to: _to,
    );
    expect(conflicts, isEmpty);
  });

  test('a clash has the same key whichever way round it is found', () {
    final a = _e('a', 9, 60, CalendarCategory.myOffice);
    final b = _e('b', 9, 60, CalendarCategory.family);
    expect(EventConflict(a, b).key, EventConflict(b, a).key);
  });

  test('a new event is warned about any overlap, same calendar or not', () {
    final existing = [
      _e('standup', 9, 30, CalendarCategory.myOffice),
      _e('lunch', 12, 60, CalendarCategory.family),
    ];
    final clashes = clashesForNewEvent(
      existing,
      DateTime.utc(2026, 11, 10, 9, 15),
      DateTime.utc(2026, 11, 10, 10),
    );
    expect(clashes.map((e) => e.id), ['standup']);
  });
}
