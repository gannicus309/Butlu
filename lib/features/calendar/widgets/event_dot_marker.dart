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

/// Small dots under a month-grid day cell, one per distinct event source
/// present that day -- mirrors iOS Calendar's day markers.
class EventDotMarkers extends StatelessWidget {
  const EventDotMarkers({super.key, required this.events});

  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final sources = events.map((e) => e.source).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final source in sources.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: colorForSource(source),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
