/// Finds a best-before / use-by date in text read off packaging.
///
/// Handles what's printed on German and English packs: 12.11.26,
/// 12.11.2026, 12/11/26, 12-11-2026, 2026-11-12, "12 NOV 2026",
/// "11.2026" / "11/26" (month only → last day of that month), and German
/// month names. Dates next to "MHD", "mindestens haltbar bis", "zu
/// verbrauchen bis", "best before", "use by", "exp" are preferred over
/// others on the pack (e.g. a packing date).
library;

const _keywords = [
  'mhd',
  'mindestens haltbar',
  'haltbar bis',
  'zu verbrauchen',
  'verbrauchen bis',
  'best before',
  'best by',
  'use by',
  'bbe',
  'bb',
  'exp',
  'expiry',
  'expires',
];

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'mär': 3,
  'mrz': 3,
  'apr': 4,
  'may': 5,
  'mai': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'okt': 10,
  'nov': 11,
  'dec': 12,
  'dez': 12,
};

class _Candidate {
  _Candidate(this.date, this.score);
  final DateTime date;
  final int score;
}

/// The most likely expiry date in [lines], or null if none looks right.
/// Dates more than a year in the past or ten years ahead are ignored --
/// they're batch numbers or prices misread as dates.
DateTime? parseExpiryDate(List<String> lines, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final earliest = DateTime(today.year - 1, today.month, today.day);
  final latest = DateTime(today.year + 10, today.month, today.day);

  final candidates = <_Candidate>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lower = line.toLowerCase();
    final keywordHere = _keywords.any(lower.contains);
    final keywordBefore =
        i > 0 && _keywords.any(lines[i - 1].toLowerCase().contains);
    for (final (date, precise) in _datesIn(line)) {
      if (date.isBefore(earliest) || date.isAfter(latest)) continue;
      var score = 0;
      if (keywordHere) score += 10;
      if (keywordBefore) score += 6;
      if (precise) score += 2;
      // Expiry dates are in the future far more often than not.
      if (!date.isBefore(DateTime(today.year, today.month, today.day))) {
        score += 3;
      }
      candidates.add(_Candidate(date, score));
    }
  }
  if (candidates.isEmpty) return null;
  // Best score wins; on a tie, the later date (a pack's expiry comes after
  // its packing/production date).
  candidates.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.date.compareTo(a.date);
  });
  return candidates.first.date;
}

int _year(String y) => y.length == 2 ? 2000 + int.parse(y) : int.parse(y);

DateTime? _valid(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final last = DateTime(y, m + 1, 0).day;
  if (d > last) return null;
  return DateTime(y, m, d);
}

/// Every date-looking thing in [text], with whether it had a day (precise)
/// or only a month.
Iterable<(DateTime, bool)> _datesIn(String text) sync* {
  // Common OCR slips in dates: O→0, l/I→1, and spaces round separators.
  final t = text
      .replaceAllMapped(
        RegExp(r'(?<=\d)[oO](?=\d)|(?<=[.\-/])[oO]|[oO](?=[.\-/]\d)'),
        (_) => '0',
      )
      .replaceAllMapped(RegExp(r'\s*([./\-])\s*'), (m) => m[1]!);
  final used = <(int, int)>[];
  bool overlaps(Match m) => used.any((r) => m.start < r.$2 && r.$1 < m.end);

  // 2026-11-12
  for (final m in RegExp(
    r'\b(20\d\d)[.\-/](\d{1,2})[.\-/](\d{1,2})\b',
  ).allMatches(t)) {
    final d = _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null) {
      used.add((m.start, m.end));
      yield (d, true);
    }
  }
  // 12.11.26 / 12.11.2026 / 12/11/26 (day first, as in Europe)
  for (final m in RegExp(
    r'\b(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{4}|\d{2})\b',
  ).allMatches(t)) {
    if (overlaps(m)) continue;
    final d = _valid(_year(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (d != null) {
      used.add((m.start, m.end));
      yield (d, true);
    }
  }
  // 12 NOV 2026 / 12. November 26 / 12NOV26
  for (final m in RegExp(
    r'\b(\d{1,2})\.?\s*([a-zA-ZäÄ]{3,9})\.?\s*(\d{4}|\d{2})\b',
  ).allMatches(t)) {
    if (overlaps(m)) continue;
    final month = _months[m[2]!.toLowerCase().substring(0, 3)];
    if (month == null) continue;
    final d = _valid(_year(m[3]!), month, int.parse(m[1]!));
    if (d != null) {
      used.add((m.start, m.end));
      yield (d, true);
    }
  }
  // 11.2026 / 11/26 -- month only: good until the end of that month.
  for (final m in RegExp(r'\b(\d{1,2})[./](\d{4}|\d{2})\b').allMatches(t)) {
    if (overlaps(m)) continue;
    final month = int.parse(m[1]!);
    if (month < 1 || month > 12) continue;
    final y = _year(m[2]!);
    yield (DateTime(y, month + 1, 0), false);
  }
}
