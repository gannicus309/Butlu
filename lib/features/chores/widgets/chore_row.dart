import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chore.dart';

/// One Reminders-style line: a round tick-off circle in the task's colour,
/// its title, and a small line of date · subtype · #tags · repeat ·
/// assignee. Tapping the text opens the details.
class ChoreRow extends StatefulWidget {
  const ChoreRow({
    super.key,
    required this.chore,
    required this.onComplete,
    required this.onOpen,
  });

  final Chore chore;
  final VoidCallback onComplete;
  final VoidCallback onOpen;

  @override
  State<ChoreRow> createState() => _ChoreRowState();
}

class _ChoreRowState extends State<ChoreRow> {
  bool _ticked = false;

  Future<void> _tick() async {
    if (_ticked) return;
    setState(() => _ticked = true);
    // Let the circle fill before the row goes, like Reminders.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    widget.onComplete();
    if (mounted) setState(() => _ticked = false);
  }

  String _dateLabel(DateTime now) {
    final c = widget.chore;
    final due = c.dueAt!;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    final dayText = switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ when diff > 1 && diff < 7 => DateFormat.EEEE().format(due),
      _ => DateFormat.MMMd().format(due),
    };
    return c.hasTime ? '$dayText ${DateFormat.jm().format(due)}' : dayText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.chore;
    final now = DateTime.now();
    final color = c.kind.color;
    final overdue = c.isOverdue(now);
    final muted = theme.colorScheme.onSurfaceVariant;

    final meta = <InlineSpan>[
      if (c.dueAt != null)
        TextSpan(
          text: _dateLabel(now),
          style: TextStyle(
            color: overdue ? ChoreKind.priority.color : muted,
            fontWeight: overdue ? FontWeight.w600 : null,
          ),
        ),
      TextSpan(text: '${c.subtype.emoji} ${c.subtype.label}'),
      if (c.repeat != ChoreRepeat.none)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat, size: 13, color: muted),
              const SizedBox(width: 2),
              Text(
                c.repeat.label,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      for (final t in c.tags)
        TextSpan(
          text: '#$t',
          style: TextStyle(color: color),
        ),
      if (c.assignee != null) TextSpan(text: '👤 ${c.assignee}'),
    ];
    final joined = <InlineSpan>[];
    for (final s in meta) {
      if (joined.isNotEmpty) joined.add(const TextSpan(text: '  ·  '));
      joined.add(s);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _ticked ? 0.45 : 1,
      child: InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _tick,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ticked ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: _ticked
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration: _ticked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (c.priority)
                          Icon(Icons.flag, size: 16, color: color),
                      ],
                    ),
                    if (c.details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          c.details,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(children: joined),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
