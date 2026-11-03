import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/event_source.dart';

Color colorForSource(EventSource source) {
  switch (source) {
    case EventSource.ios:
      return const Color(0xFF34C759); // iOS system green.
    case EventSource.outlook:
      return const Color(0xFF0A84FF); // iOS system blue.
    case EventSource.butlu:
      return const Color(0xFFFF9F0A); // iOS system orange.
  }
}

/// Parses `#RRGGBB` (as iOS reports calendar colours); null if absent/bad.
Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null || hex.length != 7) return null;
  return Color(0xFF000000 | value);
}

/// The event's own calendar colour when it came from a phone calendar (so a
/// spouse's shared calendar reads as theirs), else its source's colour.
Color colorForEvent(CalendarEvent event) =>
    colorFromHex(event.colorHex) ?? colorForSource(event.source);

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
