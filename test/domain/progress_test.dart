import 'package:time_manager/domain/activity.dart';
import 'package:time_manager/domain/app_data.dart';
import 'package:time_manager/domain/goal.dart';
import 'package:time_manager/domain/habit.dart';
import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/progress.dart';
import 'package:time_manager/domain/target_ref.dart';
import 'package:flutter_test/flutter_test.dart';

Goal goal(
  String id, {
  GoalKind kind = GoalKind.measurable,
  num? target,
  String? unit,
  String? parent,
  GoalStatus status = GoalStatus.active,
  int order = 0,
}) => Goal(
  id: id,
  title: id,
  kind: kind,
  target: target,
  unit: unit,
  parent: parent,
  status: status,
  created: DateTime(2026, 1, 1, 0, order),
);

GoalLog log(String goal, num amount) => GoalLog(
  id: 'l_$goal$amount',
  goal: goal,
  amount: amount,
  at: DateTime(2026, 10, 14),
);

Session session(TargetRef target, int minutes) => Session(
  id: 's_$minutes',
  target: target,
  start: DateTime(2026, 10, 14, 9),
  plannedMin: minutes,
  actualMin: minutes,
);

void main() {
  final wed = Day(DateTime(2026, 10, 14));
  final thu = Day(DateTime(2026, 10, 15));

  test('measurable progress is the sum of logs over the target', () {
    final data = const AppData()
        .withGoal(goal('g_lc', target: 100, unit: 'problems'))
        .withPeriods([
          PeriodDoc(period: wed, goalLogs: [log('g_lc', 20), log('g_lc', 5)]),
          PeriodDoc(period: thu, goalLogs: [log('g_lc', 20)]),
        ]);
    expect(goalAmounts(data)['g_lc'], 45);
    expect(goalProgress(data)['g_lc'], closeTo(0.45, 1e-9));
  });

  test('linked habits feed their goal: value, or goalAmount per check', () {
    final data = const AppData()
        .withGoal(goal('g_book', target: 300, unit: 'pages'))
        .withGoal(goal('g_gym', target: 50, unit: 'workouts'))
        .withHabit(
          Habit(
            id: 'h_read',
            title: 'Reading',
            kind: HabitKind.measurable,
            unit: 'pages',
            goal: 'g_book',
            created: DateTime(2026),
          ),
        )
        .withHabit(
          Habit(
            id: 'h_gym',
            title: 'Gym',
            goal: 'g_gym',
            goalAmount: 2,
            created: DateTime(2026),
          ),
        )
        .withPeriods([
          PeriodDoc(
            period: wed,
            habitEntries: const [
              HabitEntry(habit: 'h_read', value: 30),
              HabitEntry(habit: 'h_gym', value: true),
            ],
          ),
          PeriodDoc(
            period: thu,
            habitEntries: const [
              HabitEntry(habit: 'h_read', value: 15),
              HabitEntry(habit: 'h_gym', value: false),
            ],
          ),
        ]);
    final amounts = goalAmounts(data);
    expect(amounts['g_book'], 45);
    expect(amounts['g_gym'], 2);
  });

  test('sessions count only toward minute-unit goals and habits', () {
    final data = const AppData()
        .withGoal(goal('g_min', target: 600, unit: 'min'))
        .withGoal(goal('g_pages', target: 100, unit: 'pages'))
        .withGoal(goal('g_med', target: 1000, unit: 'Minutes'))
        .withHabit(
          Habit(
            id: 'h_med',
            title: 'Meditation',
            kind: HabitKind.measurable,
            unit: 'minutes',
            goal: 'g_med',
            created: DateTime(2026),
          ),
        )
        .withPeriods([
          PeriodDoc(
            period: wed,
            sessions: [
              session(const TargetRef.goal('g_min'), 50),
              session(const TargetRef.goal('g_pages'), 25),
              session(const TargetRef.habit('h_med'), 20),
            ],
            habitEntries: const [HabitEntry(habit: 'h_med', value: 10)],
          ),
        ]);
    final amounts = goalAmounts(data);
    expect(amounts['g_min'], 50);
    expect(amounts['g_pages'], isNull);
    // The habit's day value is the entry plus its sessions: 10 + 20.
    expect(amounts['g_med'], 30);
    expect(habitDayValue(data.habits['h_med']!, data.period(wed)), 30);
  });

  test('a parent averages its children, each capped at 100%', () {
    final data = const AppData()
        .withGoal(goal('g_interview', kind: GoalKind.log))
        .withGoal(
          goal('g_kaggle', target: 100, parent: 'g_interview', order: 1),
        )
        .withGoal(goal('g_lc', target: 100, parent: 'g_interview', order: 2))
        .withPeriods([
          PeriodDoc(
            period: wed,
            goalLogs: [log('g_kaggle', 150), log('g_lc', 50)],
          ),
        ]);
    final p = goalProgress(data);
    expect(p['g_kaggle'], 1.5); // a leaf may exceed 100%...
    expect(p['g_interview'], 0.75); // ...but counts as 100% for its parent
  });

  test('log-goal children count 100% when completed, else 0%', () {
    final data = const AppData()
        .withGoal(goal('g_dl', kind: GoalKind.log))
        .withGoal(
          goal(
            'g_book',
            kind: GoalKind.log,
            parent: 'g_dl',
            status: GoalStatus.completed,
          ),
        )
        .withGoal(goal('g_course', kind: GoalKind.log, parent: 'g_dl'));
    final p = goalProgress(data);
    expect(p['g_book'], isNull);
    expect(p['g_dl'], 0.5);
  });

  test('nested parents average recursively', () {
    final data = const AppData()
        .withGoal(goal('g_a'))
        .withGoal(goal('g_b', parent: 'g_a'))
        .withGoal(goal('g_c', target: 10, parent: 'g_b'))
        .withGoal(goal('g_d', target: 10, parent: 'g_a'))
        .withPeriods([
          PeriodDoc(period: wed, goalLogs: [log('g_c', 10), log('g_d', 5)]),
        ]);
    expect(goalProgress(data)['g_a'], 0.75);
  });

  test('a parent cycle from a hand-edited file does not hang', () {
    final data = const AppData()
        .withGoal(goal('g_x', target: 10, parent: 'g_y'))
        .withGoal(goal('g_y', target: 10, parent: 'g_x'));
    expect(() => goalProgress(data), returnsNormally);
  });

  test('a goal whose parent is missing is top-level', () {
    final children = childrenByParent([goal('g_orphan', parent: 'g_gone')]);
    expect(children[null]!.single.id, 'g_orphan');
  });

  test('subtreeIds includes the goal and all descendants', () {
    final data = const AppData()
        .withGoal(goal('g_a'))
        .withGoal(goal('g_b', parent: 'g_a'))
        .withGoal(goal('g_c', parent: 'g_b'))
        .withGoal(goal('g_other'));
    expect(subtreeIds(data, 'g_a'), {'g_a', 'g_b', 'g_c'});
  });

  group('newlyReachedTargets', () {
    final base = const AppData().withGoal(goal('g_1', target: 10));

    test('fires on the change that crosses 100%', () {
      final after = base.withPeriods([
        PeriodDoc(period: wed, goalLogs: [log('g_1', 10)]),
      ]);
      expect(newlyReachedTargets(base, after).map((g) => g.id), ['g_1']);
    });

    test('does not fire again once above 100% (after an undo)', () {
      final above = base.withPeriods([
        PeriodDoc(period: wed, goalLogs: [log('g_1', 12)]),
      ]);
      final more = above.withPeriods([
        PeriodDoc(period: thu, goalLogs: [log('g_1', 1)]),
      ]);
      expect(newlyReachedTargets(above, more), isEmpty);
    });

    test('ignores parents, on-hold goals and log goals', () {
      final data = const AppData()
          .withGoal(goal('g_parent', target: 1))
          .withGoal(goal('g_child', target: 100, parent: 'g_parent'))
          .withGoal(goal('g_held', target: 1, status: GoalStatus.onHold));
      final after = data.withPeriods([
        PeriodDoc(
          period: wed,
          goalLogs: [log('g_parent', 5), log('g_held', 5)],
        ),
      ]);
      expect(newlyReachedTargets(data, after), isEmpty);
    });
  });
}
