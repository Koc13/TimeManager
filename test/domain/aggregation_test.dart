import 'package:time_manager/domain/activity.dart';
import 'package:time_manager/domain/aggregation.dart';
import 'package:time_manager/domain/app_data.dart';
import 'package:time_manager/domain/goal.dart';
import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/target_ref.dart';
import 'package:time_manager/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wed = Day(DateTime(2026, 10, 14));
  final thu = Day(DateTime(2026, 10, 15));
  const w42 = Week(2026, 42);
  const october = Month(2026, 10);

  Task done(String id, DateTime at) =>
      Task(id: id, title: id, created: DateTime(2026, 10, 1), doneAt: at);

  group('doneTasks', () {
    // Tasks completed on Wed from three different lists, one on Thu, one
    // open, and one completed in November from the October list.
    final data = const AppData().withPeriods([
      PeriodDoc(
        period: wed,
        tasks: [done('day-wed', DateTime(2026, 10, 14, 18))],
      ),
      PeriodDoc(
        period: w42,
        tasks: [
          done('week-wed', DateTime(2026, 10, 14, 9)),
          done('week-thu', DateTime(2026, 10, 15, 9)),
          Task(id: 'open', title: 'open', created: DateTime(2026, 10, 1)),
        ],
      ),
      PeriodDoc(
        period: october,
        tasks: [
          done('month-wed', DateTime(2026, 10, 14, 12)),
          done('month-nov', DateTime(2026, 11, 2, 12)),
        ],
      ),
    ]);

    List<String> ids(Period p) =>
        doneTasks(data, p).map((d) => d.task.id).toList();

    test('a day page shows tasks completed that day in any list, by time', () {
      expect(ids(wed), ['week-wed', 'month-wed', 'day-wed']);
      expect(ids(thu), ['week-thu']);
    });

    test('week and month pages include every list', () {
      expect(ids(w42), ['week-wed', 'month-wed', 'day-wed', 'week-thu']);
      expect(ids(october), ['week-wed', 'month-wed', 'day-wed', 'week-thu']);
      expect(ids(const Month(2026, 11)), ['month-nov']);
    });

    test('each entry knows the list it lives in', () {
      final entry = doneTasks(data, wed).first;
      expect(entry.list, w42);
    });
  });

  group('activityIn', () {
    Session session(String id, TargetRef target, int minutes) => Session(
      id: id,
      target: target,
      start: DateTime(2026, 10, 14, 9),
      plannedMin: minutes,
      actualMin: minutes,
    );

    final data = const AppData()
        .withGoal(
          Goal(id: 'g_1', title: 'Interview prep', created: DateTime(2026)),
        )
        .withPeriods([
          PeriodDoc(
            period: wed,
            sessions: [
              session('s1', const TargetRef.goal('g_1'), 50),
              session('s2', const TargetRef.goal('g_1'), 20),
              session('s3', const TargetRef.custom('Tax forms'), 25),
            ],
            habitEntries: const [
              HabitEntry(habit: 'h_gym', value: true),
              HabitEntry(habit: 'h_read', value: 30),
              HabitEntry(habit: 'h_off', value: false),
            ],
            goalLogs: [
              GoalLog(
                id: 'l1',
                goal: 'g_1',
                amount: 25,
                at: DateTime(2026, 10, 14, 21),
              ),
            ],
          ),
          PeriodDoc(
            period: thu,
            sessions: [session('s4', const TargetRef.goal('g_1'), 30)],
            habitEntries: const [HabitEntry(habit: 'h_read', value: 12.5)],
          ),
        ]);

    test('a day groups session time by target, most time first', () {
      final a = activityIn(data, wed);
      expect(
        a.sessions.map((s) => (targetName(data, s.target), s.minutes, s.count)),
        [('Interview prep', 70, 2), ('Tax forms', 25, 1)],
      );
      expect(a.goalLogs.single.amount, 25);
    });

    test('unchecked habit entries are not activity', () {
      final habits = activityIn(data, wed).habits.map((h) => h.habit);
      expect(habits, ['h_gym', 'h_read']);
    });

    test('a week sums its days', () {
      final a = activityIn(data, w42);
      expect(a.sessions.first.minutes, 100);
      expect(a.sessions.first.count, 3);
      final reading = a.habits.firstWhere((h) => h.habit == 'h_read');
      expect((reading.days, reading.total), (2, 42.5));
    });

    test('a period with no day files is empty', () {
      expect(activityIn(data, const Week(2026, 43)).isEmpty, isTrue);
    });
  });
}
