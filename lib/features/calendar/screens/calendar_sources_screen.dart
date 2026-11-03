import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/device_calendar_info.dart';
import '../providers/calendar_providers.dart';
import '../providers/calendar_selection_provider.dart';
import '../widgets/event_dot_marker.dart';

/// Lets the user choose which of the phone's calendars Butlu imports --
/// including a spouse's iCloud calendar once it's been shared with them.
class CalendarSourcesScreen extends ConsumerWidget {
  const CalendarSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(deviceCalendarsProvider);
    // Watched so the switches rebuild when a choice is saved.
    ref.watch(calendarSelectionProvider);
    final selection = ref.read(calendarSelectionProvider.notifier);

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
              const FadeSlideIn(child: _SpouseHint()),
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
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: SwitchListTile(
                        secondary: _ColorDot(colorHex: calendar.colorHex),
                        title: Text(calendar.name),
                        subtitle: calendar.readOnly
                            ? const Text('Read-only')
                            : null,
                        value: selection.isIncluded(calendar),
                        onChanged: (on) =>
                            selection.setIncluded(calendar, on, calendars),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.colorHex});

  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorFromHex(colorHex) ?? Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _SpouseHint extends StatelessWidget {
  const _SpouseHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.people_alt_outlined, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "To add your spouse's calendar: on their iPhone, open "
                'Calendar → Calendars → ⓘ next to their calendar → Add Person, '
                'and add your Apple ID. Accept the invite on your phone and '
                'it appears here.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
