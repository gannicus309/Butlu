import 'package:butlu/features/calendar/models/calendar_category.dart';
import 'package:butlu/features/calendar/models/calendar_event.dart';
import 'package:butlu/features/calendar/models/event_dedupe.dart';
import 'package:butlu/features/calendar/models/event_source.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _e(
  String id,
  String title,
  CalendarCategory category, {
  int hour = 10,
  String? calendarName,
}) {
  final start = DateTime.utc(2026, 11, 4, hour);
  return CalendarEvent(
    id: id,
    title: title,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    timeZone: 'UTC',
    source: EventSource.ios,
    createdByUid: 'uid-1',
    calendarName: calendarName,
    category: category,
    lastModifiedAt: start,
    lastModifiedBy: EventSource.ios,
  );
}

void main() {
  test('the same meeting in famJam and Outlook shows once, as office', () {
    final merged = mergeDuplicates([
      _e('fam', 'Sprint review', CalendarCategory.family),
      _e('work', 'Sprint review', CalendarCategory.myOffice),
    ]);
    expect(merged.single.id, 'work');
  });

  test('an Outlook "Busy" block takes the famJam title, in office colour', () {
    final merged = mergeDuplicates([
      _e('fam', 'Dentist', CalendarCategory.family),
      _e('work', 'Busy', CalendarCategory.myOffice, calendarName: 'Calendar'),
    ]);
    expect(merged.single.title, 'Dentist');
    expect(merged.single.effectiveCategory, CalendarCategory.myOffice);
    expect(merged.single.calendarName, 'Calendar');
  });

  test('different events at the same time are both kept', () {
    final merged = mergeDuplicates([
      _e('a', 'Swimming', CalendarCategory.family),
      _e('b', 'Standup', CalendarCategory.myOffice),
    ]);
    expect(merged.map((e) => e.id), unorderedEquals(['a', 'b']));
  });

  test(
    'a "Busy" block is not merged when two family events share its time',
    () {
      final merged = mergeDuplicates([
        _e('a', 'Swimming', CalendarCategory.family),
        _e('b', 'Piano', CalendarCategory.family),
        _e('c', 'Busy', CalendarCategory.myOffice),
      ]);
      expect(merged, hasLength(3));
    },
  );

  test('events at different times are untouched', () {
    final merged = mergeDuplicates([
      _e('a', 'Sprint review', CalendarCategory.family, hour: 9),
      _e('b', 'Sprint review', CalendarCategory.myOffice, hour: 10),
    ]);
    expect(merged, hasLength(2));
  });
}
