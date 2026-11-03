import 'calendar_category.dart';
import 'calendar_event.dart';

/// Titles Outlook gives events it publishes without details ("free/busy"
/// only, or marked private), in English and German.
final _busyPlaceholder = RegExp(
  r'^(busy|gebucht|beschäftigt|private appointment|privater termin)$',
  caseSensitive: false,
);

bool _isBusyPlaceholder(CalendarEvent e) =>
    _busyPlaceholder.hasMatch(e.title.trim());

/// Lower wins: an office copy of a meeting beats the same meeting mirrored
/// into the family calendar, so it shows in the office colour.
int _priority(CalendarCategory c) => switch (c) {
  CalendarCategory.myOffice || CalendarCategory.partnerOffice => 0,
  CalendarCategory.butlu => 1,
  CalendarCategory.family => 2,
};

CalendarEvent _best(Iterable<CalendarEvent> events) => events.reduce(
  (a, b) =>
      _priority(b.effectiveCategory) < _priority(a.effectiveCategory) ? b : a,
);

/// Shows each real-world event once when it arrives through more than one
/// calendar -- e.g. a work meeting that's both in the subscribed Outlook
/// calendar and mirrored into famJam.
///
/// Events count as the same when they start and end at the same instant and
/// have the same title; the copy in the most specific calendar is kept. An
/// Outlook "Busy" placeholder at exactly the same time as one titled event
/// from a less specific calendar is taken to be that event: it's shown once,
/// with the real title and the office colour.
List<CalendarEvent> mergeDuplicates(List<CalendarEvent> events) {
  final bySlot = <(int, int, bool), List<CalendarEvent>>{};
  for (final e in events) {
    bySlot
        .putIfAbsent((
          e.startAt.millisecondsSinceEpoch,
          e.endAt.millisecondsSinceEpoch,
          e.isAllDay,
        ), () => [])
        .add(e);
  }

  final result = <CalendarEvent>[];
  for (final slot in bySlot.values) {
    if (slot.length == 1) {
      result.add(slot.single);
      continue;
    }
    final byTitle = <String, List<CalendarEvent>>{};
    final busy = <CalendarEvent>[];
    for (final e in slot) {
      if (_isBusyPlaceholder(e)) {
        busy.add(e);
      } else {
        byTitle.putIfAbsent(e.title.trim().toLowerCase(), () => []).add(e);
      }
    }
    final titled = [for (final group in byTitle.values) _best(group)];

    if (busy.isNotEmpty && titled.length == 1) {
      final placeholder = _best(busy);
      final real = titled.single;
      if (_priority(placeholder.effectiveCategory) <
          _priority(real.effectiveCategory)) {
        result.add(
          real.copyWith(
            category: placeholder.effectiveCategory,
            calendarName: placeholder.calendarName,
          ),
        );
        continue;
      }
    }
    result.addAll(titled);
    if (busy.isNotEmpty) result.add(_best(busy));
  }
  return result;
}
