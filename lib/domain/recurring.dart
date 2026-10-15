/// Recurring task templates and the rule that turns them into tasks.
library;

import 'app_data.dart';
import 'ids.dart';
import 'period.dart';
import 'period_doc.dart';
import 'target_ref.dart';
import 'task.dart';

enum RepeatEvery { day, weekdays, week, month }

/// When a template produces an instance, and in which list.
///
/// The list follows from the rule (its "target list"):
/// - `day`: every day, in the daily list;
/// - `weekdays`: on the chosen weekdays (1 = Mon … 7 = Sun), daily list;
/// - `week`: once per week, in the weekly list;
/// - `month` with [dayOfMonth]: on that day, in the daily list (day 31 means
///   the month's last day in shorter months);
/// - `month` without [dayOfMonth]: once per month, in the monthly list.
class RepeatRule {
  const RepeatRule.daily()
    : every = RepeatEvery.day,
      weekdays = const {},
      dayOfMonth = null;
  const RepeatRule.weekdays(this.weekdays)
    : every = RepeatEvery.weekdays,
      dayOfMonth = null;
  const RepeatRule.weekly()
    : every = RepeatEvery.week,
      weekdays = const {},
      dayOfMonth = null;
  const RepeatRule.monthly([this.dayOfMonth])
    : every = RepeatEvery.month,
      weekdays = const {};

  final RepeatEvery every;
  final Set<int> weekdays;
  final int? dayOfMonth;

  PeriodKind get listKind => switch (every) {
    RepeatEvery.day || RepeatEvery.weekdays => PeriodKind.day,
    RepeatEvery.week => PeriodKind.week,
    RepeatEvery.month => dayOfMonth == null ? PeriodKind.month : PeriodKind.day,
  };

  /// Whether the current [listKind] period (the one containing [today])
  /// should get an instance.
  bool firesOn(DateTime today) => switch (every) {
    RepeatEvery.day || RepeatEvery.week => true,
    RepeatEvery.weekdays => weekdays.contains(today.weekday),
    RepeatEvery.month =>
      dayOfMonth == null ||
          today.day == _clampDay(dayOfMonth!, today.year, today.month),
  };

  static int _clampDay(int day, int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return day > last ? last : day;
  }
}

/// A recurring task: one file in `recurring/`.
class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.title,
    this.priority = 2,
    required this.rule,
    this.link,
    this.reminderMinute,
    required this.created,
    this.lastGenerated,
    this.extra = const {},
  });

  final String id;
  final String title;
  final int priority;
  final RepeatRule rule;
  final TargetRef? link;

  /// Time of day (minutes after midnight) for each daily-list instance's
  /// reminder; ignored for weekly/monthly-list instances.
  final int? reminderMinute;
  final DateTime created;

  /// Key of the period that last got an instance. Prevents a deleted
  /// instance from coming back on the next app open.
  final String? lastGenerated;
  final Map<String, Object?> extra;

  RecurringTemplate copyWith({
    String? title,
    int? priority,
    RepeatRule? rule,
    Object? link = _keep,
    Object? reminderMinute = _keep,
    Object? lastGenerated = _keep,
  }) => RecurringTemplate(
    id: id,
    title: title ?? this.title,
    priority: priority ?? this.priority,
    rule: rule ?? this.rule,
    link: identical(link, _keep) ? this.link : link as TargetRef?,
    reminderMinute: identical(reminderMinute, _keep)
        ? this.reminderMinute
        : reminderMinute as int?,
    created: created,
    lastGenerated: identical(lastGenerated, _keep)
        ? this.lastGenerated
        : lastGenerated as String?,
    extra: extra,
  );
}

const _keep = Object();

/// Instances due now, as changed period documents plus the templates with
/// their new `lastGenerated`. Empty lists when nothing is due.
///
/// A template is skipped when its current period already got an instance
/// (`lastGenerated`), or already holds an *open* instance of it (one that
/// rolled over from an earlier period), so an unfinished "Clean room"
/// doesn't double up.
({List<PeriodDoc> docs, List<RecurringTemplate> templates})
generateRecurringTasks(AppData data, DateTime now) {
  final docs = <String, PeriodDoc>{};
  final templates = <RecurringTemplate>[];
  for (final template in data.recurring.values) {
    final rule = template.rule;
    final period = Period.of(rule.listKind, now);
    if (template.lastGenerated == period.key || !rule.firesOn(now)) continue;

    final doc = docs[period.key] ?? data.period(period);
    templates.add(template.copyWith(lastGenerated: period.key));
    final hasOpen = doc.tasks.any(
      (t) => t.recurring == template.id && t.isOpen,
    );
    if (hasOpen) continue;

    // A new day-list instance supersedes unfinished ones from earlier days
    // ("Stretch" left open yesterday isn't a separate task from today's).
    // They are dropped, not deleted, so the history still shows them.
    if (period is Day) {
      for (final old in data.periods.values) {
        if (old.period is! Day || old.period.compareTo(period) >= 0) continue;
        final stale = docs[old.period.key] ?? old;
        if (!stale.tasks.any((t) => t.recurring == template.id && t.isOpen)) {
          continue;
        }
        docs[old.period.key] = stale.copyWith(
          tasks: [
            for (final t in stale.tasks)
              t.recurring == template.id && t.isOpen
                  ? t.copyWith(droppedAt: now)
                  : t,
          ],
        );
      }
    }

    final minute = template.reminderMinute;
    final day = midnight(now);
    docs[period.key] = doc.copyWith(
      tasks: [
        ...doc.tasks,
        Task(
          id: newId('t'),
          title: template.title,
          priority: template.priority,
          link: template.link,
          recurring: template.id,
          created: now,
          reminder: minute != null && period is Day
              ? DateTime(
                  day.year,
                  day.month,
                  day.day,
                  minute ~/ 60,
                  minute % 60,
                )
              : null,
        ),
      ],
    );
  }
  return (docs: docs.values.toList(), templates: templates);
}

/// Reminders that should be scheduled right now: open tasks whose reminder
/// is still in the future, by task ID.
Map<String, ({String title, DateTime at})> reminderPlan(
  AppData data,
  DateTime now,
) => {
  for (final doc in data.periods.values)
    for (final task in doc.tasks)
      if (task.reminder case final at? when task.isOpen && at.isAfter(now))
        task.id: (title: task.title, at: at),
};
