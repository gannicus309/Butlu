import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../models/day_layout.dart';
import 'event_dot_marker.dart';

/// One day as an hour grid, like Outlook's day view: timed events are blocks
/// at their real times (overlaps side by side), all-day events sit in a strip
/// on top, and a red line marks "now" on today. Tapping a free hour calls
/// [onTapHour] with that hour, for adding an event there.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.day,
    required this.events,
    this.onTapHour,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final ValueChanged<int>? onTapHour;

  static const hourHeight = 60.0;
  static const _gutter = 56.0;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _initialOffset(),
  );
  Timer? _tick;

  bool get _isToday {
    final now = DateTime.now();
    return now.year == widget.day.year &&
        now.month == widget.day.month &&
        now.day == widget.day.day;
  }

  /// Opens just above "now" on today, else just above the first event, else
  /// at 7:00 -- the start of a working day, like Outlook.
  double _initialOffset() {
    double hours;
    if (_isToday) {
      final now = DateTime.now();
      hours = now.hour + now.minute / 60 - 1;
    } else {
      final slots = layoutDay(widget.events, widget.day);
      hours = slots.isEmpty ? 7 : slots.first.startMinute / 60 - 0.5;
    }
    return (hours.clamp(0, 24) * DayTimeline.hourHeight).toDouble();
  }

  @override
  void initState() {
    super.initState();
    // Keep the "now" line moving.
    if (_isToday) {
      _tick = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDay = widget.events.where((e) => e.isAllDay).toList();
    final slots = layoutDay(widget.events, widget.day);

    return Column(
      children: [
        if (allDay.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(DayTimeline._gutter, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final e in allDay) _AllDayChip(event: e)],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * DayTimeline.hourHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth - DayTimeline._gutter - 8;
                  return Stack(
                    children: [
                      for (var h = 0; h < 24; h++) _hourRow(context, h),
                      for (final slot in slots) _block(context, slot, width),
                      if (_isToday) _nowLine(context),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hourRow(BuildContext context, int hour) {
    final theme = Theme.of(context);
    final label = DateFormat.j().format(DateTime(2000, 1, 1, hour));
    return Positioned(
      top: hour * DayTimeline.hourHeight,
      left: 0,
      right: 0,
      height: DayTimeline.hourHeight,
      child: InkWell(
        onTap: widget.onTapHour == null ? null : () => widget.onTapHour!(hour),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: DayTimeline._gutter,
              child: Transform.translate(
                offset: const Offset(0, -7),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    hour == 0 ? '' : label,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(BuildContext context, TimelineSlot slot, double width) {
    final theme = Theme.of(context);
    final color = colorForEvent(slot.event);
    final columnWidth = width / slot.columns;
    final top = slot.startMinute / 60 * DayTimeline.hourHeight;
    final height =
        (slot.endMinute - slot.startMinute) / 60 * DayTimeline.hourHeight;
    final e = slot.event;
    final time =
        '${DateFormat.jm().format(e.startAt.toLocal())} – '
        '${DateFormat.jm().format(e.endAt.toLocal())}';

    return Positioned(
      top: top + 1,
      height: height - 2,
      left: DayTimeline._gutter + slot.column * columnWidth + 1,
      width: columnWidth - 2,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.28),
            theme.colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e.title,
              maxLines: height < 40 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (height >= 40)
              Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nowLine(BuildContext context) {
    final now = DateTime.now();
    final top = (now.hour + now.minute / 60) * DayTimeline.hourHeight;
    const red = Color(0xFFFF453A);
    return Positioned(
      top: top - 4,
      left: DayTimeline._gutter - 4,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: red,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(child: Container(height: 2, color: red)),
          ],
        ),
      ),
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorForEvent(event);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        event.title,
        style: theme.textTheme.labelMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
