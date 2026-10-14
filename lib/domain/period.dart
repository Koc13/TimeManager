/// Day / ISO week / calendar month periods, always in device local time.
///
/// Pure Dart (no Flutter, no dart:io) so a desktop build can reuse it. The
/// ISO-week maths is carried over from the old `period_key.dart`, including
/// its DST-safety rules (see [_shiftDays] and [_daysSinceEpoch]).
library;

enum PeriodKind { day, week, month }

sealed class Period implements Comparable<Period> {
  const Period();

  /// The period of [kind] containing [date].
  factory Period.of(PeriodKind kind, DateTime date) => switch (kind) {
    PeriodKind.day => DayPeriod(date),
    PeriodKind.week => WeekPeriod.containing(date),
    PeriodKind.month => MonthPeriod(date.year, date.month),
  };

  /// Inverse of [key]: '2026-10-14', '2026-W42' or '2026-10'.
  static Period parse(String key) {
    final week = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(key);
    if (week != null) {
      return WeekPeriod(int.parse(week[1]!), int.parse(week[2]!));
    }
    final day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (day != null) {
      return DayPeriod(
        DateTime(int.parse(day[1]!), int.parse(day[2]!), int.parse(day[3]!)),
      );
    }
    final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
    if (month != null) {
      return MonthPeriod(int.parse(month[1]!), int.parse(month[2]!));
    }
    throw FormatException('Not a period key', key);
  }

  static Period? tryParse(String key) {
    try {
      return parse(key);
    } on FormatException {
      return null;
    }
  }

  PeriodKind get kind;
  String get key;

  /// Local midnight of the first day.
  DateTime get start;

  /// Local midnight of the first day after the period.
  DateTime get endExclusive;

  Period get next;
  Period get previous;

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(endExclusive);

  @override
  int compareTo(Period other) => start.compareTo(other.start);

  @override
  bool operator ==(Object other) => other is Period && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

final class DayPeriod extends Period {
  DayPeriod(DateTime date) : date = midnight(date);

  final DateTime date;

  @override
  PeriodKind get kind => PeriodKind.day;
  @override
  String get key => dateKey(date);
  @override
  DateTime get start => date;
  @override
  DateTime get endExclusive => _shiftDays(date, 1);
  @override
  DayPeriod get next => DayPeriod(_shiftDays(date, 1));
  @override
  DayPeriod get previous => DayPeriod(_shiftDays(date, -1));
}

final class WeekPeriod extends Period {
  const WeekPeriod(this.isoYear, this.week);

  factory WeekPeriod.containing(DateTime date) {
    // ISO 8601: the Thursday of a date's week decides its week-year.
    final day = midnight(date);
    final thursday = _shiftDays(day, 4 - day.weekday);
    final isoYear = thursday.year;
    final week =
        (_daysSinceEpoch(thursday) - _daysSinceEpoch(_week1Monday(isoYear))) ~/
            7 +
        1;
    return WeekPeriod(isoYear, week);
  }

  final int isoYear;
  final int week;

  @override
  PeriodKind get kind => PeriodKind.week;
  @override
  String get key => '$isoYear-W${_two(week)}';
  @override
  DateTime get start => _shiftDays(_week1Monday(isoYear), (week - 1) * 7);
  @override
  DateTime get endExclusive => _shiftDays(start, 7);
  @override
  WeekPeriod get next => WeekPeriod.containing(endExclusive);
  @override
  WeekPeriod get previous => WeekPeriod.containing(_shiftDays(start, -1));
}

final class MonthPeriod extends Period {
  const MonthPeriod(this.year, this.month);

  final int year;
  final int month;

  @override
  PeriodKind get kind => PeriodKind.month;
  @override
  String get key => '${_four(year)}-${_two(month)}';
  @override
  DateTime get start => DateTime(year, month);
  // DateTime normalises month 13 to January of the next year.
  @override
  DateTime get endExclusive => DateTime(year, month + 1);
  @override
  MonthPeriod get next => MonthPeriod(endExclusive.year, endExclusive.month);
  @override
  MonthPeriod get previous {
    final prev = DateTime(year, month - 1);
    return MonthPeriod(prev.year, prev.month);
  }
}

DateTime midnight(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// 'YYYY-MM-DD' in local time.
String dateKey(DateTime date) {
  final local = date.toLocal();
  return '${_four(local.year)}-${_two(local.month)}-${_two(local.day)}';
}

/// Number of calendar days in `[start, endExclusive)`, DST-safe.
int daysBetween(DateTime start, DateTime endExclusive) =>
    _daysSinceEpoch(endExclusive) - _daysSinceEpoch(start);

// Shifts by calendar days via Y/M/D construction, not add(Duration): a
// 24h-multiple shift across a DST change lands on 23:00/01:00 instead of
// midnight.
DateTime _shiftDays(DateTime midnight, int days) =>
    DateTime(midnight.year, midnight.month, midnight.day + days);

// difference().inDays is off by an hour across DST; UTC has no DST.
int _daysSinceEpoch(DateTime localMidnight) =>
    DateTime.utc(
      localMidnight.year,
      localMidnight.month,
      localMidnight.day,
    ).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

// Jan 4 is in ISO week 1 by definition.
DateTime _week1Monday(int isoYear) {
  final jan4 = DateTime(isoYear, 1, 4);
  return _shiftDays(jan4, -(jan4.weekday - 1));
}

String _two(int n) => n.toString().padLeft(2, '0');
String _four(int n) => n.toString().padLeft(4, '0');
