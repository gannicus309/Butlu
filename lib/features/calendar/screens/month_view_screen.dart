import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../providers/calendar_providers.dart';
import '../providers/calendar_selection_provider.dart';
import '../widgets/event_dot_marker.dart';
import '../widgets/event_list_tile.dart';

class MonthViewScreen extends ConsumerStatefulWidget {
  const MonthViewScreen({super.key});

  @override
  ConsumerState<MonthViewScreen> createState() => _MonthViewScreenState();
}

class _MonthViewScreenState extends ConsumerState<MonthViewScreen>
    with SingleTickerProviderStateMixin {
  bool _syncing = false;
  bool _syncAgain = false;
  late final AppLifecycleListener _lifecycle;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    // Pull in iOS changes whenever the user comes back to the app, e.g. after
    // adding an event in iOS Calendar or accepting a shared calendar.
    _lifecycle = AppLifecycleListener(onResume: _syncNow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstSync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _firstSync() async {
    final ios = ref.read(iosCalendarRepositoryProvider);
    if (!await ios.hasPermission()) await ios.requestPermission();
    await _syncNow(quiet: true);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _syncNow({bool quiet = false}) async {
    if (!mounted) return;
    if (_syncing) {
      // A sync is already running against the old calendar choice; run once
      // more afterwards rather than dropping this request.
      _syncAgain = true;
      return;
    }
    setState(() => _syncing = true);
    _spin.repeat();
    try {
      do {
        _syncAgain = false;
        await ref.read(calendarSyncServiceProvider).runFullSync();
      } while (_syncAgain && mounted);
    } catch (e) {
      if (mounted && !quiet) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } finally {
      _spin.stop();
      _spin.reset();
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync straight away when calendars are switched on/off in the picker.
    ref.listen(calendarSelectionProvider, (previous, next) => _syncNow());

    final scheme = Theme.of(context).colorScheme;
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDay = ref.watch(selectedDayProvider) ?? DateTime.now();
    final eventsByDay = ref.watch(eventsByDayProvider);
    final dayEvents =
        eventsByDay[DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
        )] ??
        const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            onPressed: () => context.go('/calendar/sources'),
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Choose calendars',
          ),
          IconButton(
            onPressed: _syncing ? null : _syncNow,
            icon: RotationTransition(
              turns: _spin,
              child: const Icon(Icons.sync),
            ),
            tooltip: 'Sync with iOS Calendar',
          ),
          const AccountAvatarButton(),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: focusedMonth,
            selectedDayPredicate: (day) => _isSameDay(day, selectedDay),
            eventLoader: (day) =>
                eventsByDay[DateTime(day.year, day.month, day.day)] ?? const [],
            onPageChanged: (focused) =>
                ref.read(focusedMonthProvider.notifier).state = focused,
            onDaySelected: (selected, focused) {
              if (_isSameDay(selected, selectedDay)) {
                _openDay(selected);
                return;
              }
              HapticFeedback.selectionClick();
              ref.read(selectedDayProvider.notifier).state = selected;
              ref.read(focusedMonthProvider.notifier).state = focused;
            },
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            rowHeight: 48,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: Theme.of(context).textTheme.titleMedium!,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
              selectedDecoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
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
          const SizedBox(height: 4),
          _DayHeader(
            day: selectedDay,
            count: dayEvents.length,
            onOpen: () => _openDay(selectedDay),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: dayEvents.isEmpty
                  ? _NothingPlanned(
                      key: ValueKey('empty-$selectedDay'),
                      onAdd: () => _openDay(selectedDay),
                    )
                  : ListView.builder(
                      key: ValueKey('list-$selectedDay'),
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: dayEvents.length,
                      itemBuilder: (context, index) => FadeSlideIn(
                        delay: FadeSlideIn.staggerDelay(index),
                        child: EventListTile(event: dayEvents[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDay(DateTime day) =>
      context.go('/calendar/day/${DateFormat('yyyy-MM-dd').format(day)}');
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.count,
    required this.onOpen,
  });

  final DateTime day;
  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  DateFormat.MMMMEEEEd().format(day),
                  key: ValueKey(day),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            Text(
              count == 0 ? '' : '$count event${count == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _NothingPlanned extends StatelessWidget {
  const _NothingPlanned({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scrollable so it never overflows the little space left under the month
    // grid on a short screen.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.wb_sunny_outlined, size: 40, color: scheme.outline),
          const SizedBox(height: 8),
          Text(
            'Nothing planned',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add event'),
          ),
        ],
      ),
    );
  }
}
