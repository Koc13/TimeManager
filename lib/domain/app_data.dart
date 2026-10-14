import 'goal.dart';
import 'habit.dart';
import 'period.dart';
import 'period_doc.dart';
import 'recurring.dart';

/// The whole data set, loaded in memory. Immutable: changes produce a new
/// AppData, which is what lets Riverpod rebuild only on real changes.
class AppData {
  const AppData({
    this.goals = const {},
    this.habits = const {},
    this.recurring = const {},
    this.periods = const {},
  });

  final Map<String, Goal> goals;
  final Map<String, Habit> habits;
  final Map<String, RecurringTemplate> recurring;

  /// By period key ('2026-10-14', '2026-W42', '2026-10').
  final Map<String, PeriodDoc> periods;

  PeriodDoc period(Period period) =>
      periods[period.key] ?? PeriodDoc.empty(period);

  AppData _copy({
    Map<String, Goal>? goals,
    Map<String, Habit>? habits,
    Map<String, RecurringTemplate>? recurring,
    Map<String, PeriodDoc>? periods,
  }) => AppData(
    goals: goals ?? this.goals,
    habits: habits ?? this.habits,
    recurring: recurring ?? this.recurring,
    periods: periods ?? this.periods,
  );

  AppData withPeriods(Iterable<PeriodDoc> docs) =>
      _copy(periods: {...periods, for (final doc in docs) doc.period.key: doc});

  AppData withGoal(Goal goal) => _copy(goals: {...goals, goal.id: goal});

  AppData withoutGoal(String id) => _copy(goals: {...goals}..remove(id));

  AppData withHabit(Habit habit) => _copy(habits: {...habits, habit.id: habit});

  AppData withoutHabit(String id) => _copy(habits: {...habits}..remove(id));

  AppData withRecurring(RecurringTemplate t) =>
      _copy(recurring: {...recurring, t.id: t});

  AppData withoutRecurring(String id) =>
      _copy(recurring: {...recurring}..remove(id));
}
