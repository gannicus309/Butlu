import 'dart:ui' show Color;

enum ChoreSubtype {
  house('House', '🏠'),
  admin('Admin', '📄'),
  butlu('Butlu', '🧺'),
  personal('Personal', '🙂'),
  office('Office', '💼');

  const ChoreSubtype(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum ChoreRepeat {
  none('Never'),
  daily('Daily'),
  weekly('Weekly'),
  biweekly('Every 2 weeks'),
  monthly('Monthly');

  const ChoreRepeat(this.label);
  final String label;

  /// The next due date after [from] for a repeating task.
  /// The next due date after [from] for a repeating task. Counts calendar
  /// days rather than adding 24-hour spans, so a daylight-saving change
  /// doesn't shift it to 23:00 the day before.
  DateTime next(DateTime from) => switch (this) {
    ChoreRepeat.none => from,
    ChoreRepeat.daily => _addDays(from, 1),
    ChoreRepeat.weekly => _addDays(from, 7),
    ChoreRepeat.biweekly => _addDays(from, 14),
    // Same day next month, clamped (31 Jan -> 28/29 Feb).
    ChoreRepeat.monthly => _addMonth(from),
  };

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  static DateTime _addMonth(DateTime d) {
    final lastDay = DateTime(d.year, d.month + 2, 0).day;
    return DateTime(
      d.year,
      d.month + 1,
      d.day > lastDay ? lastDay : d.day,
      d.hour,
      d.minute,
    );
  }
}

/// The three colours of the Chores list.
enum ChoreKind {
  priority('Priority', Color(0xFFFF453A)),
  repeating('Repeating', Color(0xFF0A84FF)),
  special('Special', Color(0xFF199E70));

  const ChoreKind(this.label, this.color);
  final String label;
  final Color color;
}

/// A family to-do, Apple Reminders-style.
class Chore {
  const Chore({
    required this.id,
    required this.title,
    this.details = '',
    this.dueAt,
    this.hasTime = false,
    this.subtype = ChoreSubtype.house,
    this.tags = const [],
    this.repeat = ChoreRepeat.none,
    this.priority = false,
    this.assignee,
    this.createdAt,
  });

  final String id;
  final String title;
  final String details;

  /// Local date (and time if [hasTime]) it's due; null for "someday".
  final DateTime? dueAt;
  final bool hasTime;
  final ChoreSubtype subtype;
  final List<String> tags;
  final ChoreRepeat repeat;

  /// Flagged as top priority -- shown red, sorted first. A priority task can
  /// also repeat.
  final bool priority;

  /// Who it's for, as shown on screen (a family member's name, "Partner",
  /// ...); null means anyone.
  final String? assignee;
  final DateTime? createdAt;

  /// Priority wins over repeating; anything else is a one-off "special".
  ChoreKind get kind => priority
      ? ChoreKind.priority
      : repeat != ChoreRepeat.none
      ? ChoreKind.repeating
      : ChoreKind.special;

  bool isOverdue(DateTime now) {
    final due = dueAt;
    if (due == null) return false;
    if (hasTime) return due.isBefore(now);
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  bool isDueToday(DateTime now) {
    final due = dueAt;
    return due != null &&
        due.year == now.year &&
        due.month == now.month &&
        due.day == now.day;
  }

  Chore copyWith({
    String? title,
    String? details,
    DateTime? dueAt,
    bool clearDue = false,
    bool? hasTime,
    ChoreSubtype? subtype,
    List<String>? tags,
    ChoreRepeat? repeat,
    bool? priority,
    String? assignee,
    bool clearAssignee = false,
  }) => Chore(
    id: id,
    title: title ?? this.title,
    details: details ?? this.details,
    dueAt: clearDue ? null : (dueAt ?? this.dueAt),
    hasTime: hasTime ?? this.hasTime,
    subtype: subtype ?? this.subtype,
    tags: tags ?? this.tags,
    repeat: repeat ?? this.repeat,
    priority: priority ?? this.priority,
    assignee: clearAssignee ? null : (assignee ?? this.assignee),
    createdAt: createdAt,
  );
}

/// One completed task, kept for the load charts. Copies what the task was
/// at the time, so charts stay right after a task is edited or deleted.
class ChoreCompletion {
  const ChoreCompletion({
    required this.choreId,
    required this.title,
    required this.kind,
    required this.subtype,
    required this.assignee,
    required this.completedAt,
  });

  final String choreId;
  final String title;
  final ChoreKind kind;
  final ChoreSubtype subtype;

  /// Who it was for, or "Anyone".
  final String assignee;
  final DateTime completedAt;
}

/// A ready-made task to add in one tap.
class ChoreSuggestion {
  const ChoreSuggestion(
    this.title,
    this.subtype, {
    this.repeat = ChoreRepeat.none,
    this.priority = false,
    this.tags = const [],
  });

  final String title;
  final ChoreSubtype subtype;
  final ChoreRepeat repeat;
  final bool priority;
  final List<String> tags;
}

const kChoreSuggestions = [
  ChoreSuggestion(
    'Take out the bins',
    ChoreSubtype.house,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion('Vacuum', ChoreSubtype.house, repeat: ChoreRepeat.weekly),
  ChoreSuggestion(
    'Clean the bathroom',
    ChoreSubtype.house,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion('Laundry', ChoreSubtype.house, repeat: ChoreRepeat.weekly),
  ChoreSuggestion(
    'Change bed sheets',
    ChoreSubtype.house,
    repeat: ChoreRepeat.biweekly,
  ),
  ChoreSuggestion(
    'Water the plants',
    ChoreSubtype.house,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion('Dishes', ChoreSubtype.house, repeat: ChoreRepeat.daily),
  ChoreSuggestion(
    'Mop the floors',
    ChoreSubtype.house,
    repeat: ChoreRepeat.biweekly,
  ),
  ChoreSuggestion(
    'Clean the fridge',
    ChoreSubtype.house,
    repeat: ChoreRepeat.monthly,
  ),
  ChoreSuggestion(
    'Weekly shop',
    ChoreSubtype.butlu,
    repeat: ChoreRepeat.weekly,
    tags: ['shopping'],
  ),
  ChoreSuggestion(
    'Plan meals for the week',
    ChoreSubtype.butlu,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion(
    'Check what\'s expiring',
    ChoreSubtype.butlu,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion(
    'Pay rent',
    ChoreSubtype.admin,
    repeat: ChoreRepeat.monthly,
    priority: true,
    tags: ['bills'],
  ),
  ChoreSuggestion(
    'Check bank statements',
    ChoreSubtype.admin,
    repeat: ChoreRepeat.monthly,
    tags: ['money'],
  ),
  ChoreSuggestion('File tax documents', ChoreSubtype.admin, tags: ['tax']),
  ChoreSuggestion('Book a doctor\'s appointment', ChoreSubtype.personal),
  ChoreSuggestion(
    'Call parents',
    ChoreSubtype.personal,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion('Exercise', ChoreSubtype.personal, repeat: ChoreRepeat.daily),
  ChoreSuggestion(
    'Submit timesheet',
    ChoreSubtype.office,
    repeat: ChoreRepeat.weekly,
  ),
  ChoreSuggestion(
    'Expense report',
    ChoreSubtype.office,
    repeat: ChoreRepeat.monthly,
  ),
];
