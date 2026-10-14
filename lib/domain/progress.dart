/// Goal progress, derived from recorded facts. Never
/// stored: logs, habit entries and sessions are the facts; totals and
/// percentages are recomputed from them.
library;

import 'activity.dart';
import 'app_data.dart';
import 'goal.dart';
import 'habit.dart';
import 'period.dart';
import 'period_doc.dart';
import 'target_ref.dart';

/// Whether a unit means minutes, so session time counts toward it.
bool isMinutes(String? unit) => const {
  'min',
  'mins',
  'minute',
  'minutes',
}.contains(unit?.trim().toLowerCase());

/// A habit's value on one day: the entry (a yes/no check counts 1), plus
/// timer sessions on the habit when its unit is minutes.
num habitDayValue(Habit habit, PeriodDoc day) {
  num value = 0;
  for (final e in day.habitEntries) {
    if (e.habit == habit.id) value += e.amount;
  }
  if (isMinutes(habit.unit)) {
    for (final s in day.sessions) {
      if (s.target == TargetRef.habit(habit.id)) value += s.actualMin;
    }
  }
  return value;
}

/// Everything ever counted toward each goal's target, by goal ID:
/// - goal log amounts,
/// - linked habits: a measurable habit's day value, or `goalAmount` per
///   checked day of a yes/no habit,
/// - sessions on the goal itself when its unit is minutes.
///
/// One pass over all day files, so the goals screen doesn't rescan the
/// whole history once per goal.
Map<String, num> goalAmounts(AppData data) {
  final amounts = <String, num>{};
  void add(String goal, num amount) =>
      amounts[goal] = (amounts[goal] ?? 0) + amount;

  final minuteGoals = {
    for (final g in data.goals.values)
      if (isMinutes(g.unit)) g.id,
  };
  final linkedHabits = [
    for (final h in data.habits.values)
      if (h.goal != null) h,
  ];

  for (final day in data.periods.values) {
    if (day.period is! Day) continue;
    for (final log in day.goalLogs) {
      if (log.amount != null) add(log.goal, log.amount!);
    }
    for (final s in day.sessions) {
      final id = s.target.id;
      if (s.target.type == TargetType.goal && minuteGoals.contains(id)) {
        add(id!, s.actualMin);
      }
    }
    for (final habit in linkedHabits) {
      final value = habitDayValue(habit, day);
      if (value == 0) continue;
      add(
        habit.goal!,
        habit.kind == HabitKind.measurable ? value : habit.goalAmount,
      );
    }
  }
  return amounts;
}

/// Progress of every goal as a fraction (1.0 = done), or null when a goal
/// has no meaningful percentage: a log goal without children, or a
/// measurable goal without a target.
///
/// - A goal with children shows the average of its children, each capped
///   at 100%. A child with no percentage of its own counts as 100% when
///   completed and 0% otherwise, so a log-goal child still moves its parent.
/// - A measurable leaf is its amount / target (may exceed 1).
Map<String, double?> goalProgress(AppData data, [Map<String, num>? amounts]) {
  amounts ??= goalAmounts(data);
  final children = childrenByParent(data.goals.values);
  final result = <String, double?>{};

  double? progressOf(Goal goal, Set<String> visiting) {
    if (result.containsKey(goal.id)) return result[goal.id];
    // A hand-edited file could make a parent cycle; treat it as a leaf.
    final kids = visiting.add(goal.id) ? children[goal.id] ?? [] : <Goal>[];
    double? value;
    if (kids.isNotEmpty) {
      final parts = [
        for (final kid in kids)
          (progressOf(kid, visiting) ??
                  (kid.status == GoalStatus.completed ? 1.0 : 0.0))
              .clamp(0.0, 1.0),
      ];
      value = parts.reduce((a, b) => a + b) / parts.length;
    } else if (goal.kind == GoalKind.measurable && (goal.target ?? 0) > 0) {
      value = (amounts![goal.id] ?? 0) / goal.target!;
    }
    visiting.remove(goal.id);
    return result[goal.id] = value;
  }

  for (final goal in data.goals.values) {
    progressOf(goal, {});
  }
  return result;
}

/// Children of each goal, by parent ID, in creation order. A child whose
/// parent doesn't exist (deleted, or a typo in a hand-edited file) is
/// listed under the `null` key, i.e. treated as top-level.
Map<String?, List<Goal>> childrenByParent(Iterable<Goal> goals) {
  final ids = {for (final g in goals) g.id};
  final map = <String?, List<Goal>>{};
  final sorted = goals.toList()..sort((a, b) => a.created.compareTo(b.created));
  for (final goal in sorted) {
    final parent = ids.contains(goal.parent) && goal.parent != goal.id
        ? goal.parent
        : null;
    (map[parent] ??= []).add(goal);
  }
  return map;
}

/// [goal] and every goal below it. Used to keep the parent picker from
/// offering a goal's own descendants (which would create a cycle).
Set<String> subtreeIds(AppData data, String goal) {
  final children = childrenByParent(data.goals.values);
  final ids = <String>{};
  void walk(String id) {
    if (!ids.add(id)) return;
    for (final child in children[id] ?? const <Goal>[]) {
      walk(child.id);
    }
  }

  walk(goal);
  return ids;
}

/// All logs for [goal], newest first, each with the day file it lives in.
List<({Day day, GoalLog log})> logsOf(AppData data, String goal) => [
  for (final doc in data.periods.values)
    if (doc.period case final Day day)
      for (final log in doc.goalLogs)
        if (log.goal == goal) (day: day, log: log),
]..sort((a, b) => b.log.at.compareTo(a.log.at));

/// Measurable goals without children that crossed 100% between [before]
/// and [after], and are still active. Transition-based on purpose: after
/// the user undoes an automatic completion, the goal stays above 100% and
/// must not be completed again on the next unrelated change.
List<Goal> newlyReachedTargets(AppData before, AppData after) {
  final was = goalProgress(before);
  final now = goalProgress(after);
  final parents = childrenByParent(after.goals.values);
  return [
    for (final goal in after.goals.values)
      if (goal.kind == GoalKind.measurable &&
          goal.status == GoalStatus.active &&
          (parents[goal.id] ?? const []).isEmpty &&
          (was[goal.id] ?? 0) < 1 &&
          (now[goal.id] ?? 0) >= 1)
        goal,
  ];
}
