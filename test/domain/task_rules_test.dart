import 'package:time_manager/domain/app_data.dart';
import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/task.dart';
import 'package:time_manager/domain/task_rules.dart';
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

    test('daily lists do not roll over automatically', () {
      final data = const AppData().withPeriods([
        PeriodDoc(period: yesterday, tasks: [task('a')]),
      ]);
      expect(rollover(data, now), isEmpty);
    });

    test('weeks and months roll over to the current week and month', () {
      final data = const AppData().withPeriods([
        PeriodDoc(period: const Week(2026, 41), tasks: [task('w')]),
        PeriodDoc(period: const Month(2026, 9), tasks: [task('m')]),
      ]);
      final after = data.withPeriods(rollover(data, now));
      expect(after.period(const Week(2026, 42)).tasks.single.id, 'w');
      expect(after.period(const Month(2026, 10)).tasks.single.id, 'm');
      expect(after.period(const Week(2026, 42)).tasks.single.rolledOver, 1);
      expect(after.period(const Week(2026, 41)).tasks, isEmpty);
    });

    test('a task rolled twice counts 2; done and dropped stay put', () {
      final data = const AppData().withPeriods([
        PeriodDoc(
          period: const Week(2026, 41),
          tasks: [
            task('a'),
            task('done', doneAt: DateTime(2026, 10, 6)),
            Task(id: 'dropped', title: 'x', created: now, droppedAt: now),
          ],
        ),
      ]);
      final once = data.withPeriods(rollover(data, now));
      final twice = once.withPeriods(rollover(once, DateTime(2026, 10, 21)));
      expect(twice.period(const Week(2026, 43)).tasks.single.rolledOver, 2);
      expect(twice.period(const Week(2026, 41)).tasks.map((t) => t.id), [
        'done',
        'dropped',
      ]);
      expect(rollover(twice, DateTime(2026, 10, 21, 8)), isEmpty);
    });
  });

  group('leftovers', () {
    final now = DateTime(2026, 10, 14, 21);
    final mon = Day(DateTime(2026, 10, 12));
    final tue = Day(DateTime(2026, 10, 13));
    final wed = Day(now);
    final thu = wed.next;
    final data = const AppData().withPeriods([
      PeriodDoc(period: mon, tasks: [task('mon-open')]),
      PeriodDoc(
        period: tue,
        tasks: [
          task('tue-open'),
          task('tue-done', doneAt: DateTime(2026, 10, 13)),
          Task(id: 'tue-dropped', title: 'x', created: now, droppedAt: now),
        ],
      ),
      PeriodDoc(period: wed, tasks: [task('wed-open')]),
      PeriodDoc(period: thu, tasks: [task('thu-planned')]),
    ]);

    List<String> ids(Day day) =>
        leftovers(data, day, now).map((l) => l.task.id).toList();

    test('today offers open tasks from earlier days, oldest first', () {
      expect(ids(wed), ['mon-open', 'tue-open']);
    });

    test('tomorrow also offers what is still open today', () {
      expect(ids(thu), ['mon-open', 'tue-open', 'wed-open']);
    });

    test('past days and later future days offer nothing', () {
      expect(ids(tue), isEmpty);
      expect(ids(thu.next), isEmpty);
    });
  });
}
