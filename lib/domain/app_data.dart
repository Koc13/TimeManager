import 'goal.dart';
import 'habit.dart';
import 'period.dart';
import 'period_doc.dart';

/// The whole data set, loaded in memory. Immutable: changes produce a new
/// AppData, which is what lets Riverpod rebuild only on real changes.
class AppData {
  const AppData({
    this.goals = const {},
    this.habits = const {},
    this.periods = const {},
  });

  final Map<String, Goal> goals;
  final Map<String, Habit> habits;

  /// By period key ('2026-10-14', '2026-W42', '2026-10').
  final Map<String, PeriodDoc> periods;

  PeriodDoc period(Period period) =>
      periods[period.key] ?? PeriodDoc.empty(period);

  AppData withPeriods(Iterable<PeriodDoc> docs) => AppData(
    goals: goals,
    habits: habits,
    periods: {...periods, for (final doc in docs) doc.period.key: doc},
  );

  AppData withGoal(Goal goal) => AppData(
    goals: {...goals, goal.id: goal},
    habits: habits,
    periods: periods,
  );

  AppData withHabit(Habit habit) => AppData(
    goals: goals,
    habits: {...habits, habit.id: habit},
    periods: periods,
  );

  AppData withoutGoal(String id) =>
      AppData(goals: {...goals}..remove(id), habits: habits, periods: periods);

  AppData withoutHabit(String id) =>
      AppData(goals: goals, habits: {...habits}..remove(id), periods: periods);
}
