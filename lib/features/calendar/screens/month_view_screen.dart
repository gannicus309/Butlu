import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/calendar_providers.dart';
import '../widgets/event_dot_marker.dart';

class MonthViewScreen extends ConsumerWidget {
  const MonthViewScreen({super.key});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsByDay = ref.watch(eventsByDayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: focusedMonth,
            selectedDayPredicate: (day) =>
                selectedDay != null && _isSameDay(day, selectedDay),
            eventLoader: (day) =>
                eventsByDay[DateTime(day.year, day.month, day.day)] ?? const [],
            onPageChanged: (focused) =>
                ref.read(focusedMonthProvider.notifier).state = focused,
            onDaySelected: (selected, focused) {
              ref.read(selectedDayProvider.notifier).state = selected;
              ref.read(focusedMonthProvider.notifier).state = focused;
              context.go(
                '/calendar/day/${DateFormat('yyyy-MM-dd').format(selected)}',
              );
            },
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) => Positioned(
                bottom: 4,
                child: EventDotMarkers(events: events.cast()),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: Text(
                'Tap a day to see its events',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
