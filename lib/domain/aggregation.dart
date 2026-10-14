/// Derived views for a period's Done page. Nothing here is stored.
library;

import 'activity.dart';
import 'app_data.dart';
import 'period.dart';
import 'target_ref.dart';
import 'task.dart';

/// A completed task plus the list it lives in (needed to uncheck it).
typedef DoneTask = ({Period list, Task task});

/// Tasks completed during [period], from any list (day, week or month),
/// oldest completion first. A task checked off on Wednesday in the
/// weekly list shows on Wednesday's, that week's and that month's page.
List<DoneTask> doneTasks(AppData data, Period period) {
  final done = <DoneTask>[
    for (final doc in data.periods.values)
      for (final task in doc.tasks)
        if (task.doneAt case final at? when period.contains(at))
          (list: doc.period, task: task),
  ];
  done.sort((a, b) => a.task.doneAt!.compareTo(b.task.doneAt!));
  return done;
}

/// Total session time for one target within a period.
typedef SessionTotal = ({TargetRef target, int minutes, int count});

/// One habit's entries within a period. [total] sums measurable values;
/// for yes/no habits it is the number of days checked.
typedef HabitTotal = ({String habit, int days, num total});

class PeriodActivity {
  const PeriodActivity({
    required this.sessions,
    required this.habits,
    required this.goalLogs,
  });

  /// Most time first.
  final List<SessionTotal> sessions;
  final List<HabitTotal> habits;

  /// Oldest first.
  final List<GoalLog> goalLogs;

  bool get isEmpty => sessions.isEmpty && habits.isEmpty && goalLogs.isEmpty;
}

/// Sessions, habit entries and goal logs recorded on the days of [period].
/// They only live in day files, so a week or month sums its days.
PeriodActivity activityIn(AppData data, Period period) {
  final days = data.periods.values.where(
    (doc) => doc.period is Day && period.contains(doc.period.start),
  );

  final sessions = <TargetRef, ({int minutes, int count})>{};
  final habits = <String, ({int days, num total})>{};
  final logs = <GoalLog>[];
  for (final day in days) {
    for (final s in day.sessions) {
      final prev = sessions[s.target] ?? (minutes: 0, count: 0);
      sessions[s.target] = (
        minutes: prev.minutes + s.actualMin,
        count: prev.count + 1,
      );
    }
    for (final e in day.habitEntries) {
      final value = e.amount;
      if (value == 0) continue; // an unchecked/zero entry isn't activity
      final prev = habits[e.habit] ?? (days: 0, total: 0);
      habits[e.habit] = (days: prev.days + 1, total: prev.total + value);
    }
    logs.addAll(day.goalLogs);
  }

  return PeriodActivity(
    sessions: [
      for (final MapEntry(key: target, value: v) in sessions.entries)
        (target: target, minutes: v.minutes, count: v.count),
    ]..sort((a, b) => b.minutes.compareTo(a.minutes)),
    habits: [
      for (final MapEntry(key: habit, value: v) in habits.entries)
        (habit: habit, days: v.days, total: v.total),
    ],
    goalLogs: logs..sort((a, b) => a.at.compareTo(b.at)),
  );
}

/// Display name for a target; records may have been deleted since.
String targetName(AppData data, TargetRef target) => switch (target.type) {
  TargetType.goal => data.goals[target.id]?.title ?? '(deleted goal)',
  TargetType.habit => data.habits[target.id]?.title ?? '(deleted habit)',
  TargetType.custom => target.name!,
};
