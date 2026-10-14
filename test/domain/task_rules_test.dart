import 'package:first_app/domain/app_data.dart';
import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/period_doc.dart';
import 'package:first_app/domain/task.dart';
import 'package:first_app/domain/task_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Task task(
  String id, {
  int priority = 2,
  DateTime? deadline,
  DateTime? doneAt,
  int created = 0,
}) => Task(
  id: id,
  title: id,
  priority: priority,
  deadline: deadline,
  doneAt: doneAt,
  created: DateTime(2026, 1, 1, 0, created),
);

void main() {
  test(
    'open tasks sort by priority, then deadline (none last), then created',
    () {
      final sorted = openTasksSorted([
        task('low', priority: 3),
        task('mid-no-deadline', created: 1),
        task('done', priority: 1, doneAt: DateTime(2026)),
        task('mid-late', deadline: DateTime(2026, 10, 20)),
        task('high', priority: 1),
        task('mid-early', deadline: DateTime(2026, 10, 15)),
        task('mid-no-deadline-older', created: 0),
      ]);
      expect(sorted.map((t) => t.id), [
        'high',
        'mid-early',
        'mid-late',
        'mid-no-deadline-older',
        'mid-no-deadline',
        'low',
      ]);
    },
  );

  group('moveTarget', () {
    final today = DateTime(2026, 10, 14, 9); // Wed, W42

    test('down from the current month lands in the current week/day', () {
      const october = Month(2026, 10);
      expect(moveTarget(october, PeriodKind.week, today).key, '2026-W42');
      expect(moveTarget(october, PeriodKind.day, today).key, '2026-10-14');
    });

    test('down from a future period lands on its first day', () {
      const november = Month(2026, 11);
      expect(moveTarget(november, PeriodKind.day, today).key, '2026-11-01');
      // Sun 1 Nov 2026 is in W44.
      expect(moveTarget(november, PeriodKind.week, today).key, '2026-W44');
    });

    test('up from a day lands in the week and month containing it', () {
      final friday = Day(DateTime(2026, 10, 30));
      expect(moveTarget(friday, PeriodKind.week, today).key, '2026-W44');
      expect(moveTarget(friday, PeriodKind.month, today).key, '2026-10');
    });
  });

  group('rollover', () {
    final now = DateTime(2026, 10, 14, 7);
    final yesterday = Day(DateTime(2026, 10, 13));
    final twoDaysAgo = Day(DateTime(2026, 10, 12));
    final today = Day(DateTime(2026, 10, 14));
    final tomorrow = Day(DateTime(2026, 10, 15));

    test('moves open tasks of past days into today, oldest first', () {
      final data = const AppData().withPeriods([
        PeriodDoc(period: twoDaysAgo, tasks: [task('a')]),
        PeriodDoc(
          period: yesterday,
          tasks: [
            task('b'),
            task('done', doneAt: DateTime(2026, 10, 13, 20)),
          ],
        ),
        PeriodDoc(period: today, tasks: [task('existing')]),
        PeriodDoc(period: tomorrow, tasks: [task('future')]),
      ]);
      final after = data.withPeriods(rollover(data, now));

      expect(after.period(today).tasks.map((t) => t.id), [
        'existing',
        'a',
        'b',
      ]);
      expect(after.period(today).tasks[1].rolledOver, 1);
      expect(after.period(twoDaysAgo).tasks, isEmpty);
      // Done tasks stay where they were completed; the future is untouched.
      expect(after.period(yesterday).tasks.single.id, 'done');
      expect(after.period(tomorrow).tasks.single.id, 'future');
    });

    test('weeks and months roll over to the current week and month', () {
      final data = const AppData().withPeriods([
        PeriodDoc(period: const Week(2026, 41), tasks: [task('w')]),
        PeriodDoc(period: const Month(2026, 9), tasks: [task('m')]),
      ]);
      final after = data.withPeriods(rollover(data, now));
      expect(after.period(const Week(2026, 42)).tasks.single.id, 'w');
      expect(after.period(const Month(2026, 10)).tasks.single.id, 'm');
    });

    test('a task rolled twice counts 2, and nothing to do changes nothing', () {
      final data = const AppData().withPeriods([
        PeriodDoc(period: yesterday, tasks: [task('a')]),
      ]);
      final once = data.withPeriods(rollover(data, now));
      final twice = once.withPeriods(rollover(once, DateTime(2026, 10, 15, 7)));
      expect(twice.period(tomorrow).tasks.single.rolledOver, 2);
      expect(rollover(twice, DateTime(2026, 10, 15, 8)), isEmpty);
    });
  });
}
