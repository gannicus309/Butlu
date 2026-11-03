import 'package:flutter/material.dart';

import '../models/calendar_event.dart';

/// One of the four family colours -- see [CalendarCategory].
Color colorForEvent(CalendarEvent event) => event.effectiveCategory.color;

/// Small dots under a month-grid day cell, one per distinct calendar colour
/// present that day -- mirrors iOS Calendar's day markers.
class EventDotMarkers extends StatelessWidget {
  const EventDotMarkers({super.key, required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final colors = events.map(colorForEvent).toSet();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in colors.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}
