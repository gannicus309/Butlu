import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../models/event_source.dart';
import 'event_dot_marker.dart';

class EventListTile extends StatelessWidget {
  const EventListTile({super.key, required this.event});

  final CalendarEvent event;

  String get _timeLabel => event.isAllDay
      ? 'All day'
      : '${DateFormat.jm().format(event.startAt.toLocal())} – '
            '${DateFormat.jm().format(event.endAt.toLocal())}';

  /// Which calendar the event belongs to: the phone calendar's own name for
  /// iOS imports (e.g. a spouse's shared calendar), else where it came from.
  String get _calendarLabel {
    final name = event.calendarName;
    if (name != null && name.isNotEmpty) return name;
    switch (event.source) {
      case EventSource.ios:
        return 'iOS Calendar';
      case EventSource.outlook:
        return 'Outlook';
      case EventSource.butlu:
        return 'Butlu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorForEvent(event);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(_timeLabel, style: theme.textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _calendarLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
