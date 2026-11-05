import 'chore.dart';

enum LoadPeriod {
  daily('Daily', 7),
  weekly('Weekly', 8),
  monthly('Monthly', 6);

  const LoadPeriod(this.label, this.buckets);
  final String label;

  /// How many of these periods the bar chart shows, ending with the
  /// current one.
  final int buckets;
}

/// One bar of the load chart: a day, week or month, and how many tasks
/// were completed in it, split by a grouping key (assignee or kind).
class LoadBucket {
  const LoadBucket({required this.start, required this.counts});

  final DateTime start;
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of [d]'s week.
DateTime _week(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

DateTime _month(DateTime d) => DateTime(d.year, d.month);

DateTime bucketStart(LoadPeriod period, DateTime d) => switch (period) {
  LoadPeriod.daily => _day(d),
  LoadPeriod.weekly => _week(d),
  LoadPeriod.monthly => _month(d),
};

DateTime _previous(LoadPeriod period, DateTime start) => switch (period) {
  LoadPeriod.daily => DateTime(start.year, start.month, start.day - 1),
  LoadPeriod.weekly => DateTime(start.year, start.month, start.day - 7),
  LoadPeriod.monthly => DateTime(start.year, start.month - 1),
};

/// The last [LoadPeriod.buckets] days/weeks/months up to [now], oldest
/// first, with completions counted by [groupBy]. Empty periods are kept,
/// so the chart has a steady axis.
List<LoadBucket> loadBuckets(
  List<ChoreCompletion> completions, {
  required LoadPeriod period,
  required String Function(ChoreCompletion) groupBy,
  required DateTime now,
}) {
  final starts = <DateTime>[bucketStart(period, now)];
  while (starts.length < period.buckets) {
    starts.insert(0, _previous(period, starts.first));
  }
  final byStart = {for (final s in starts) s: <String, int>{}};
  for (final c in completions) {
    final counts = byStart[bucketStart(period, c.completedAt)];
    if (counts == null) continue;
    final key = groupBy(c);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return [for (final s in starts) LoadBucket(start: s, counts: byStart[s]!)];
}

/// Completions within the shown range, counted by [groupBy] -- the pie
/// chart's slices, largest first.
List<MapEntry<String, int>> loadShare(
  List<ChoreCompletion> completions, {
  required LoadPeriod period,
  required String Function(ChoreCompletion) groupBy,
  required DateTime now,
}) {
  final buckets = loadBuckets(
    completions,
    period: period,
    groupBy: groupBy,
    now: now,
  );
  final totals = <String, int>{};
  for (final b in buckets) {
    b.counts.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v);
  }
  return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// The next due date for a repeating task completed at [now]: steps
/// forward from its due date until it's in the future, so finishing a
/// task that's three weeks overdue doesn't leave it still overdue.
DateTime nextDue(Chore chore, DateTime now) {
  final today = _day(now);
  var next = chore.repeat.next(chore.dueAt ?? today);
  while (!_day(next).isAfter(today)) {
    next = chore.repeat.next(next);
  }
  return next;
}
