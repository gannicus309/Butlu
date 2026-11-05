import 'package:butlu/features/chores/models/chore.dart';
import 'package:butlu/features/chores/models/chore_load.dart';
import 'package:flutter_test/flutter_test.dart';

ChoreCompletion _done(
  String who,
  DateTime at, {
  ChoreKind kind = ChoreKind.special,
}) => ChoreCompletion(
  choreId: 'x',
  title: 'x',
  kind: kind,
  subtype: ChoreSubtype.house,
  assignee: who,
  completedAt: at,
);

// Thursday.
final _now = DateTime(2026, 11, 5, 18);

void main() {
  test('kind: priority beats repeating beats special', () {
    const base = Chore(id: 'a', title: 'a');
    expect(base.kind, ChoreKind.special);
    expect(base.copyWith(repeat: ChoreRepeat.weekly).kind, ChoreKind.repeating);
    expect(
      base.copyWith(repeat: ChoreRepeat.weekly, priority: true).kind,
      ChoreKind.priority,
    );
  });

  test('daily buckets cover the last 7 days and count by assignee', () {
    final buckets = loadBuckets(
      [
        _done('Ganesh', DateTime(2026, 11, 5, 9)),
        _done('Ganesh', DateTime(2026, 11, 5, 20)),
        _done('Partner', DateTime(2026, 11, 3)),
        _done('Partner', DateTime(2026, 10, 20)), // Too old: dropped.
      ],
      period: LoadPeriod.daily,
      groupBy: (c) => c.assignee,
      now: _now,
    );
    expect(buckets, hasLength(7));
    expect(buckets.first.start, DateTime(2026, 10, 30));
    expect(buckets.last.counts, {'Ganesh': 2});
    expect(buckets[4].counts, {'Partner': 1});
  });

  test('weeks start on Monday, months on the 1st', () {
    final weeks = loadBuckets(
      [_done('A', DateTime(2026, 11, 2))],
      period: LoadPeriod.weekly,
      groupBy: (c) => c.assignee,
      now: _now,
    );
    expect(weeks.last.start, DateTime(2026, 11, 2));
    expect(weeks.last.total, 1);
    final months = loadBuckets(
      const [],
      period: LoadPeriod.monthly,
      groupBy: (c) => c.assignee,
      now: _now,
    );
    expect(months.first.start, DateTime(2026, 6));
    expect(months.last.start, DateTime(2026, 11));
  });

  test('share sums the shown range, largest first', () {
    final share = loadShare(
      [
        _done('A', DateTime(2026, 11, 5), kind: ChoreKind.priority),
        _done('B', DateTime(2026, 11, 4), kind: ChoreKind.repeating),
        _done('B', DateTime(2026, 11, 1), kind: ChoreKind.repeating),
      ],
      period: LoadPeriod.weekly,
      groupBy: (c) => c.kind.label,
      now: _now,
    );
    expect(share.first.key, 'Repeating');
    expect(share.first.value, 2);
  });

  test('a repeating task moves to its next date after today', () {
    final weekly = Chore(
      id: 'bins',
      title: 'Bins',
      repeat: ChoreRepeat.weekly,
      dueAt: DateTime(2026, 10, 15), // Three weeks overdue.
    );
    expect(nextDue(weekly, _now), DateTime(2026, 11, 12));
    final monthly = Chore(
      id: 'rent',
      title: 'Rent',
      repeat: ChoreRepeat.monthly,
      dueAt: DateTime(2026, 1, 31),
    );
    expect(ChoreRepeat.monthly.next(monthly.dueAt!), DateTime(2026, 2, 28));
  });
}
