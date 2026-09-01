import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import 'event_dot_marker.dart';

class EventListTile extends StatelessWidget {
  const EventListTile({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final timeLabel = event.isAllDay
        ? 'All day'
        : '${DateFormat.jm().format(event.startAt.toLocal())} - '
            '${DateFormat.jm().format(event.endAt.toLocal())}';

    return ListTile(
      leading: Container(
        width: 4,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colorForSource(event.source),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      minLeadingWidth: 4,
      title: Text(event.title),
      subtitle: Text(
        event.notes.isEmpty ? timeLabel : '$timeLabel\n${event.notes}',
      ),
      isThreeLine: event.notes.isNotEmpty,
    );
  }
}
