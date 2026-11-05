import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/chore.dart';
import '../models/chore_load.dart';
import '../providers/chore_providers.dart';

/// Who's doing how much: completed tasks per day/week/month as stacked
/// columns, the share of the whole as a segmented bar, and what's still
/// open per person -- by person or by kind of task.
///
/// Colours follow the dataviz rules: people get the first three categorical
/// slots in a fixed order (validated all-pairs on the dark surface), with
/// anyone further folded into "Other"; kinds use their own validated
/// red/blue/green. Text never wears a series colour.
class ChoreLoadScreen extends ConsumerStatefulWidget {
  const ChoreLoadScreen({super.key});

  @override
  ConsumerState<ChoreLoadScreen> createState() => _ChoreLoadScreenState();
}

enum _GroupBy { person, kind }

const _peopleColors = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)];
const _otherColor = Color(0xFF6B7280);
const _other = 'Other';

class _ChoreLoadScreenState extends ConsumerState<ChoreLoadScreen> {
  LoadPeriod _period = LoadPeriod.weekly;
  _GroupBy _groupBy = _GroupBy.person;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = ref.watch(choreLogProvider).value ?? const <ChoreCompletion>[];
    final open = ref.watch(choresProvider).value ?? const <Chore>[];
    final now = DateTime.now();

    // People in a fixed order -- alphabetical over everyone ever seen, so a
    // person's colour never changes when the period or data does.
    final everyone = <String>{
      for (final c in log) c.assignee,
      for (final c in open) c.assignee ?? 'Anyone',
    }.toList()..sort();
    final shownPeople = everyone.take(3).toList();
    String personKey(String name) => shownPeople.contains(name) ? name : _other;
    Color personColor(String key) {
      final i = shownPeople.indexOf(key);
      return i < 0 ? _otherColor : _peopleColors[i];
    }

    final keys = _groupBy == _GroupBy.person
        ? [...shownPeople, if (everyone.length > 3) _other]
        : [for (final k in ChoreKind.values) k.label];
    Color colorOf(String key) => _groupBy == _GroupBy.person
        ? personColor(key)
        : ChoreKind.values.firstWhere((k) => k.label == key).color;
    String groupKey(ChoreCompletion c) =>
        _groupBy == _GroupBy.person ? personKey(c.assignee) : c.kind.label;

    final buckets = loadBuckets(
      log,
      period: _period,
      groupBy: groupKey,
      now: now,
    );
    final share = {
      for (final e in loadShare(
        log,
        period: _period,
        groupBy: groupKey,
        now: now,
      ))
        e.key: e.value,
    };
    final total = share.values.fold(0, (a, b) => a + b);
    final current = buckets.last.total;

    final openBy = <String, int>{};
    for (final c in open) {
      final key = _groupBy == _GroupBy.person
          ? personKey(c.assignee ?? 'Anyone')
          : c.kind.label;
      openBy[key] = (openBy[key] ?? 0) + 1;
    }

    final periodNoun = switch (_period) {
      LoadPeriod.daily => 'today',
      LoadPeriod.weekly => 'this week',
      LoadPeriod.monthly => 'this month',
    };
    final rangeNoun = switch (_period) {
      LoadPeriod.daily => 'last 7 days',
      LoadPeriod.weekly => 'last 8 weeks',
      LoadPeriod.monthly => 'last 6 months',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Chore load')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Filters, one row, above everything they control.
          Row(
            children: [
              Expanded(
                child: SegmentedButton<LoadPeriod>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in LoadPeriod.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _period = s.first;
                      _selected = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<_GroupBy>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _GroupBy.person,
                label: Text('By person'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: _GroupBy.kind,
                label: Text('By type'),
                icon: Icon(Icons.category_outlined),
              ),
            ],
            selected: {_groupBy},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              setState(() {
                _groupBy = s.first;
                _selected = null;
              });
            },
          ),
          const SizedBox(height: 20),
          // Headline number.
          Text(
            '$current',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'tasks done $periodNoun · $total in the $rangeNoun',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _Legend(keys: keys, colorOf: colorOf),
          const SizedBox(height: 12),
          _StackedColumns(
            buckets: buckets,
            keys: keys,
            colorOf: colorOf,
            period: _period,
            selected: _selected,
            onSelect: (i) =>
                setState(() => _selected = _selected == i ? null : i),
          ),
          if (_selected != null)
            _BucketDetail(
              bucket: buckets[_selected!],
              keys: keys,
              colorOf: colorOf,
              period: _period,
            ),
          const SizedBox(height: 28),
          Text('Share of done tasks', style: theme.textTheme.titleMedium),
          Text(
            rangeNoun[0].toUpperCase() + rangeNoun.substring(1),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SegmentedBar(counts: share, keys: keys, colorOf: colorOf),
          const SizedBox(height: 28),
          Text('Open now', style: theme.textTheme.titleMedium),
          Text(
            'Tasks still to do',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _SegmentedBar(counts: openBy, keys: keys, colorOf: colorOf),
          const SizedBox(height: 28),
          // Table view: every number, no colour needed to read it.
          Text('Numbers', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          _Table(keys: keys, colorOf: colorOf, done: share, open: openBy),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.keys, required this.colorOf});

  final List<String> keys;
  final Color Function(String) colorOf;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final k in keys)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colorOf(k),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(k, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
    ],
  );
}

String _bucketLabel(LoadPeriod p, DateTime start) => switch (p) {
  LoadPeriod.daily => DateFormat.E().format(start),
  LoadPeriod.weekly => DateFormat.MMMd().format(start),
  LoadPeriod.monthly => DateFormat.MMM().format(start),
};

/// Stacked columns, one per day/week/month. Bars are at most 24px wide
/// with a 4px rounded top, square at the baseline, and a 2px surface gap
/// between segments. Tapping a column shows its breakdown.
class _StackedColumns extends StatelessWidget {
  const _StackedColumns({
    required this.buckets,
    required this.keys,
    required this.colorOf,
    required this.period,
    required this.selected,
    required this.onSelect,
  });

  final List<LoadBucket> buckets;
  final List<String> keys;
  final Color Function(String) colorOf;
  final LoadPeriod period;
  final int? selected;
  final ValueChanged<int> onSelect;

  static const _plotHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxTotal = buckets.fold(0, (m, b) => b.total > m ? b.total : m);
    // A round top value for the single gridline.
    final top = maxTotal <= 4 ? 4 : ((maxTotal + 4) ~/ 5) * 5;

    return SizedBox(
      height: _plotHeight + 40,
      child: Stack(
        children: [
          // Recessive gridline at the top value, and the baseline.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$top',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 24,
            top: _plotHeight,
            child: Container(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          Positioned.fill(
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < buckets.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(i);
                      },
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: selected == null || selected == i ? 1 : 0.4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (buckets[i].total > 0 &&
                                (i == buckets.length - 1 || selected == i))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${buckets[i].total}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            _column(buckets[i], top, surface),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 32,
                              child: Text(
                                _bucketLabel(period, buckets[i].start),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _column(LoadBucket b, int top, Color surface) {
    final segments = [
      for (final k in keys)
        if ((b.counts[k] ?? 0) > 0) (k, b.counts[k]!),
    ];
    final height = b.total / top * _plotHeight;
    if (segments.isEmpty) return const SizedBox(height: 0, width: 24);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, h, _) => SizedBox(
        width: 24,
        height: h,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          child: Column(
            children: [
              // Drawn top-down so the first key sits on the baseline.
              for (var j = segments.length - 1; j >= 0; j--) ...[
                Expanded(
                  flex: segments[j].$2,
                  child: Container(color: colorOf(segments[j].$1)),
                ),
                if (j > 0) Container(height: 2, color: surface),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BucketDetail extends StatelessWidget {
  const _BucketDetail({
    required this.bucket,
    required this.keys,
    required this.colorOf,
    required this.period,
  });

  final LoadBucket bucket;
  final List<String> keys;
  final Color Function(String) colorOf;
  final LoadPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (period) {
      LoadPeriod.daily => DateFormat.MMMEd().format(bucket.start),
      LoadPeriod.weekly => 'Week of ${DateFormat.MMMd().format(bucket.start)}',
      LoadPeriod.monthly => DateFormat.yMMMM().format(bucket.start),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title · ${bucket.total} done',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final k in keys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: colorOf(k)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(k)),
                    Text('${bucket.counts[k] ?? 0}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The part-to-whole view (in place of a pie): one tall bar split into its
/// parts, each with its share printed inside when it fits.
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.counts,
    required this.keys,
    required this.colorOf,
  });

  final Map<String, int> counts;
  final List<String> keys;
  final Color Function(String) colorOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) {
      return Text(
        'Nothing yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final parts = [
      for (final k in keys)
        if ((counts[k] ?? 0) > 0) (k, counts[k]!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: Row(
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: parts[i].$2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorOf(parts[i].$1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: LayoutBuilder(
                      builder: (context, c) => c.maxWidth < 34
                          ? const SizedBox.shrink()
                          : Text(
                              '${(parts[i].$2 * 100 / total).round()}%',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          parts.map((p) => p.$1).join('  ·  '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.keys,
    required this.colorOf,
    required this.done,
    required this.open,
  });

  final List<String> keys;
  final Color Function(String) colorOf;
  final Map<String, int> done;
  final Map<String, int> open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(64),
        2: FixedColumnWidth(64),
      },
      children: [
        TableRow(
          children: [
            Text('', style: head),
            Text('DONE', style: head, textAlign: TextAlign.right),
            Text('OPEN', style: head, textAlign: TextAlign.right),
          ],
        ),
        for (final k in keys)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: colorOf(k)),
                    const SizedBox(width: 8),
                    Text(k),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${done[k] ?? 0}', textAlign: TextAlign.right),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${open[k] ?? 0}', textAlign: TextAlign.right),
              ),
            ],
          ),
      ],
    );
  }
}
