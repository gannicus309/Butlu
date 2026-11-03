import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/calendar_category.dart';
import '../models/device_calendar_info.dart';
import '../providers/calendar_providers.dart';
import '../providers/calendar_selection_provider.dart';

/// Lets the user choose which of the phone's calendars Butlu imports, and
/// which colour role each one has: My office, Wife's office or Family. Both
/// office Outlook calendars reach the phone as subscribed (ICS) calendars.
class CalendarSourcesScreen extends ConsumerWidget {
  const CalendarSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(deviceCalendarsProvider);
    final lastSync = ref.watch(lastCalendarSyncProvider);
    // Watched so rows rebuild when a choice is saved.
    ref.watch(calendarSelectionProvider);
    ref.watch(calendarRolesProvider);
    final selection = ref.read(calendarSelectionProvider.notifier);
    final roles = ref.read(calendarRolesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendars')),
      body: calendarsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text("Couldn't load calendars: $e")),
        data: (calendars) {
          if (calendars.isEmpty) {
            return const EmptyState(
              icon: Icons.event_busy_outlined,
              message:
                  'No calendars found.\n'
                  'Allow calendar access for Butlu in iOS Settings.',
            );
          }
          final groups = <String, List<DeviceCalendarInfo>>{};
          for (final c in calendars) {
            groups.putIfAbsent(c.accountName ?? 'Other', () => []).add(c);
          }
          var index = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (lastSync != null)
                FadeSlideIn(child: _SyncStatus(report: lastSync)),
              const FadeSlideIn(child: _Legend()),
              const SizedBox(height: 8),
              const FadeSlideIn(
                delay: Duration(milliseconds: 60),
                child: _OutlookHint(),
              ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                for (final calendar in entry.value)
                  FadeSlideIn(
                    delay: FadeSlideIn.staggerDelay(index++),
                    child: _CalendarRow(
                      calendar: calendar,
                      included: selection.isIncluded(calendar),
                      role: roles.roleOf(calendar),
                      eventCount: lastSync?.eventsPerCalendar[calendar.id],
                      onIncludedChanged: (on) {
                        HapticFeedback.selectionClick();
                        selection.setIncluded(calendar, on, calendars);
                      },
                      onPickRole: () async {
                        final picked = await _pickRole(
                          context,
                          calendar,
                          roles.roleOf(calendar),
                        );
                        if (picked != null) roles.setRole(calendar, picked);
                      },
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<CalendarCategory?> _pickRole(
    BuildContext context,
    DeviceCalendarInfo calendar,
    CalendarCategory current,
  ) {
    return showModalBottomSheet<CalendarCategory>(
      context: context,
      // Above the tab bar, not tucked behind it.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Show "${calendar.name}" as',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final category in CalendarCategory.assignable)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: _Dot(color: category.color, size: 18),
                title: Text(category.label),
                trailing: category == current
                    ? Icon(Icons.check, color: category.color)
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required this.calendar,
    required this.included,
    required this.role,
    required this.eventCount,
    required this.onIncludedChanged,
    required this.onPickRole,
  });

  final DeviceCalendarInfo calendar;
  final bool included;
  final CalendarCategory role;

  /// Events imported from this calendar in the last sync (null before one).
  final int? eventCount;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback onPickRole;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: included ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 16, right: 8),
          onTap: onPickRole,
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _Dot(key: ValueKey(role), color: role.color, size: 16),
          ),
          title: Text(calendar.name),
          subtitle: Text(
            [
              role.label,
              if (calendar.readOnly) 'Read-only',
              if (included && eventCount != null)
                eventCount == 1 ? '1 event' : '$eventCount events',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: role.color),
          ),
          trailing: Switch(value: included, onChanged: onIncludedChanged),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }
}

/// The four colours, so the picker explains itself.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final category in CalendarCategory.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(color: category.color, size: 10),
                  const SizedBox(width: 6),
                  Text(
                    category.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OutlookHint extends StatelessWidget {
  const _OutlookHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: scheme.onSecondaryContainer);
    return Card(
      color: scheme.secondaryContainer,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.work_outline, color: scheme.onSecondaryContainer),
          title: Text('Adding an office Outlook calendar', style: style),
          iconColor: scheme.onSecondaryContainer,
          collapsedIconColor: scheme.onSecondaryContainer,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              '1. In Outlook on the web: Settings → Calendar → Shared '
              'calendars → Publish a calendar. Pick the calendar, choose '
              '"Can view all details", Publish, and copy the ICS link.\n'
              '2. On this iPhone: Settings → Apps → Calendar → Calendar '
              'Accounts → Add Account → Other → Add Subscribed Calendar, and '
              'paste the link.\n'
              '3. Come back here and tap the new calendar to show it as '
              '"My office" or "Wife\'s office".\n\n'
              'Your wife does step 1 for her work calendar and sends you the '
              'link; you do step 2 on your phone.',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}

/// When the last sync ran and whether it worked -- the only place a failed
/// background sync is visible on a release build.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.report});

  final CalendarSyncReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = report.error;
    final time = TimeOfDay.fromDateTime(report.at).format(context);
    final total = report.eventsPerCalendar.values.fold(0, (a, b) => a + b);
    return Card(
      color: error == null ? null : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error == null ? Icons.check_circle_outline : Icons.error_outline,
              color: error == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                error == null
                    ? 'Last synced at $time · $total events imported'
                    : 'Sync failed at $time:\n$error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: error == null
                      ? null
                      : theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
