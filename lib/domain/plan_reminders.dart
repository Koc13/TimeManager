/// Reminders to plan and review the day, week and month: what they are,
/// their defaults, and when they next fire. Pure: scheduling is elsewhere.
library;

import 'period.dart';

enum PlanReminder {
  dayPlan(PeriodKind.day, 'Plan the day', "Check today's list and leftovers."),
  dayReview(
    PeriodKind.day,
    'Evening review',
    'Write your journal and plan tomorrow.',
  ),
  weekPlan(PeriodKind.week, 'Plan the week', "Set this week's tasks."),
  weekReview(PeriodKind.week, 'Weekly review', 'Look back at this week.'),
  monthPlan(PeriodKind.month, 'Plan the month', "Set this month's tasks."),
  monthReview(PeriodKind.month, 'Monthly review', 'Look back at this month.');

  const PlanReminder(this.kind, this.title, this.body);

  /// Which list the reminder is about; tapping it opens that list.
  final PeriodKind kind;
  final String title;
  final String body;

  ReminderTime get defaultTime => switch (this) {
    dayPlan => const ReminderTime(minute: 8 * 60),
    dayReview => const ReminderTime(minute: 21 * 60 + 30),
    weekPlan => const ReminderTime(minute: 8 * 60, weekday: DateTime.monday),
    weekReview => const ReminderTime(minute: 20 * 60, weekday: DateTime.sunday),
    monthPlan => const ReminderTime(minute: 8 * 60, monthDay: 1),
    monthReview => const ReminderTime(minute: 20 * 60, monthDay: lastDay),
  };
}

/// `monthDay` value meaning the month's last day.
const lastDay = 0;

/// When a reminder fires. [weekday] (1 = Mon … 7 = Sun) is used by weekly
/// reminders, [monthDay] (1–28, or [lastDay]) by monthly ones.
class ReminderTime {
  const ReminderTime({
    required this.minute,
    this.weekday = DateTime.monday,
    this.monthDay = 1,
    this.enabled = true,
  });

  /// Minutes after midnight.
  final int minute;
  final int weekday;
  final int monthDay;
  final bool enabled;

  ReminderTime copyWith({
    int? minute,
    int? weekday,
    int? monthDay,
    bool? enabled,
  }) => ReminderTime(
    minute: minute ?? this.minute,
    weekday: weekday ?? this.weekday,
    monthDay: monthDay ?? this.monthDay,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'minute': minute,
    'weekday': weekday,
    'month_day': monthDay,
  };

  static ReminderTime fromJson(Object? json, ReminderTime fallback) {
    if (json is! Map) return fallback;
    int read(String key, int def, int min, int max) => switch (json[key]) {
      final int v when v >= min && v <= max => v,
      _ => def,
    };
    return ReminderTime(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      minute: read('minute', fallback.minute, 0, 24 * 60 - 1),
      weekday: read('weekday', fallback.weekday, 1, 7),
      monthDay: read('month_day', fallback.monthDay, 0, 28),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime &&
      other.minute == minute &&
      other.weekday == weekday &&
      other.monthDay == monthDay &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(minute, weekday, monthDay, enabled);
}

/// The next [count] times [reminder] fires strictly after [now], in local
/// time. Days are stepped by calendar date (not 24 h), so the time of day
/// stays put across DST changes.
List<DateTime> nextOccurrences(
  PlanReminder reminder,
  ReminderTime time,
  DateTime now, {
  int count = 1,
}) {
  final result = <DateTime>[];
  var day = midnight(now);
  // A month has at most 31 days, so 400 days always finds 12 monthly hits.
  for (var i = 0; i < 400 && result.length < count; i++) {
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      time.minute ~/ 60,
      time.minute % 60,
    );
    if (at.isAfter(now) && _firesOn(reminder.kind, time, day)) result.add(at);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return result;
}

bool _firesOn(PeriodKind kind, ReminderTime time, DateTime day) =>
    switch (kind) {
      PeriodKind.day => true,
      PeriodKind.week => day.weekday == time.weekday,
      PeriodKind.month =>
        day.day ==
            (time.monthDay == lastDay
                ? DateTime(day.year, day.month + 1, 0).day
                : time.monthDay),
    };
