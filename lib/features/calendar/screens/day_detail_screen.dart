import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_providers.dart' show authStateProvider;
import '../models/calendar_event.dart';
import '../models/event_source.dart';
import '../providers/calendar_providers.dart';
import '../widgets/day_timeline.dart';

/// A day as an hour grid (see [DayTimeline]). Swipe left/right for the next
/// or previous day; tap a free hour, or the + button, to add an event.
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  /// Pages are days relative to [widget.date]; starting mid-range lets the
  /// user swipe a long way in either direction.
  static const _origin = 10000;
  late final PageController _pages = PageController(initialPage: _origin);
  late DateTime _day = _dateOnly(widget.date);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _dayForPage(int page) => DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day + page - _origin,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _addEvent(DateTime day, int hour) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'New event · ${DateFormat.MMMd().add_jm().format(DateTime(day.year, day.month, day.day, hour))}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final startAt = DateTime(day.year, day.month, day.day, hour).toUtc();
    final nowUtc = DateTime.now().toUtc();
    final event = CalendarEvent(
      id: const Uuid().v4(),
      title: trimmed,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      timeZone: 'local',
      source: EventSource.butlu,
      createdByUid: uid,
      lastModifiedAt: nowUtc,
      lastModifiedBy: EventSource.butlu,
    );
    await ref.read(firestoreEventRepositoryProvider).upsert(event);
  }

  /// The + button adds at the next full hour on today, else at 9:00.
  int get _defaultHour {
    final now = DateTime.now();
    if (_dateOnly(now) == _day) return (now.hour + 1).clamp(0, 23);
    return 9;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            // Short enough to fit next to the back and Today buttons.
            DateFormat.yMMMEd().format(_day),
            key: ValueKey(_day),
          ),
        ),
        actions: [
          if (_day != _dateOnly(DateTime.now()))
            TextButton(
              onPressed: () {
                final today = _dateOnly(DateTime.now());
                final offset = today.difference(_dateOnly(widget.date)).inDays;
                _pages.animateToPage(
                  _origin + offset,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Text('Today'),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        onPageChanged: (page) {
          HapticFeedback.selectionClick();
          setState(() => _day = _dayForPage(page));
          // Keep the month view on the day the user ends up on.
          ref.read(selectedDayProvider.notifier).state = _day;
          ref.read(focusedMonthProvider.notifier).state = _day;
        },
        itemBuilder: (context, page) {
          final day = _dayForPage(page);
          return Consumer(
            builder: (context, ref, _) => DayTimeline(
              day: day,
              events: ref.watch(eventsForDayProvider(day)),
              onTapHour: (hour) => _addEvent(day, hour),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEvent(_day, _defaultHour),
        child: const Icon(Icons.add),
      ),
    );
  }
}
