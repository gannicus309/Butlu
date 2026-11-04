import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../shared/widgets/account_avatar_button.dart';
import '../providers/calendar_providers.dart';
import '../widgets/event_dot_marker.dart';

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
    await ref.read(clashNotifierProvider).requestPermission();
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
        final perCalendar = await ref
            .read(calendarSyncServiceProvider)
            .runFullSync();
        ref.read(lastCalendarSyncProvider.notifier).state = CalendarSyncReport(
          at: DateTime.now(),
          eventsPerCalendar: perCalendar,
        );
      } while (_syncAgain && mounted);
    } catch (e, st) {
      debugPrint('Calendar sync failed: $e\n$st');
      // Kept for the picker too: release builds log nowhere the user (or a
      // developer without a debugger) can see.
      if (mounted) {
        ref.read(lastCalendarSyncProvider.notifier).state = CalendarSyncReport(
          at: DateTime.now(),
          error: '$e',
        );
      }
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
    // Re-sync straight away when calendars are switched on/off or given a
    // different colour role in the picker. Listening to the sync service
    // itself, not the picker's providers: it's rebuilt from those choices,
    // so by the time this fires the new service already uses them. (A
    // listener on the choices fired before that rebuild and synced with the
    // old ones.)
    ref.listen(calendarSyncServiceProvider, (previous, next) => _syncNow());
    // Lives here because this screen stays mounted for as long as the app
    // shows the family's calendar, whichever tab is open.
    ref.listen(
      upcomingConflictsProvider,
      (previous, next) => ref.read(clashNotifierProvider).notifyNew(next),
    );

    final scheme = Theme.of(context).colorScheme;
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDay = ref.watch(selectedDayProvider) ?? DateTime.now();
    final eventsByDay = ref.watch(eventsByDayProvider);
    final eventsError = ref.watch(eventsProvider).error;

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
          Expanded(
            child: TableCalendar(
              // Fills the screen now the day list below it is gone; a day's
              // detail is its hour-by-hour timeline, one tap away.
              shouldFillViewport: true,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: focusedMonth,
              selectedDayPredicate: (day) => _isSameDay(day, selectedDay),
              eventLoader: (day) =>
                  eventsByDay[DateTime(day.year, day.month, day.day)] ??
                  const [],
              onPageChanged: (focused) =>
                  ref.read(focusedMonthProvider.notifier).state = focused,
              onDaySelected: (selected, focused) {
                HapticFeedback.selectionClick();
                ref.read(selectedDayProvider.notifier).state = selected;
                ref.read(focusedMonthProvider.notifier).state = focused;
                _openDay(selected);
              },
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              startingDayOfWeek: StartingDayOfWeek.monday,
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
                // Just under the day number: the cells are tall now the grid
                // fills the screen, and dots at the cell bottom looked
                // detached from their day.
                markerBuilder: (context, day, events) => Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, 0.55),
                    child: EventDotMarkers(events: events.cast()),
                  ),
                ),
              ),
            ),
          ),
          // A broken stored event fails the whole live stream, which would
          // otherwise just look like an empty calendar.
          if (eventsError != null)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  "Couldn't load events: $eventsError",
                  style: TextStyle(color: scheme.onErrorContainer),
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
