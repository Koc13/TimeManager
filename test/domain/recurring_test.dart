import 'package:time_manager/domain/app_data.dart';
import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/recurring.dart';
import 'package:time_manager/domain/task.dart';
import 'package:time_manager/storage/codecs.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringTemplate template(RepeatRule rule, {String? last, int? reminder}) =>
    RecurringTemplate(
      id: 'r_1',
      title: 'Clean room',
      rule: rule,
      created: DateTime(2026, 10, 1),
      lastGenerated: last,
      reminderMinute: reminder,
    );

void main() {
  final wed = DateTime(2026, 10, 14, 7); // Wednesday
  final sun = DateTime(2026, 10, 18, 7);

  group('RepeatRule.firesOn', () {
    test('weekdays fire only on their days', () {
      const rule = RepeatRule.weekdays({7});
      expect(rule.firesOn(wed), isFalse);
      expect(rule.firesOn(sun), isTrue);
    });

    test('monthly on day 31 means the last day of shorter months', () {
      const rule = RepeatRule.monthly(31);
      expect(rule.firesOn(DateTime(2026, 2, 28)), isTrue);
      expect(rule.firesOn(DateTime(2024, 2, 29)), isTrue);
      expect(rule.firesOn(DateTime(2024, 2, 28)), isFalse);
      expect(rule.firesOn(DateTime(2026, 10, 31)), isTrue);
    });

    test('each rule implies its list', () {
      expect(const RepeatRule.daily().listKind, PeriodKind.day);
      expect(const RepeatRule.weekly().listKind, PeriodKind.week);
      expect(const RepeatRule.monthly().listKind, PeriodKind.month);
      expect(const RepeatRule.monthly(1).listKind, PeriodKind.day);
    });
  });

  group('generateRecurring', () {
    test('creates the due instance once per period', () {
      final data = const AppData().withRecurring(
        template(const RepeatRule.daily(), reminder: 19 * 60),
      );
      final first = generateRecurringTasks(data, wed);
      final task = first.docs.single.tasks.single;
      expect(first.docs.single.period, Day(wed));
      expect(task.recurring, 'r_1');
      expect(task.reminder, DateTime(2026, 10, 14, 19));
      expect(first.templates.single.lastGenerated, '2026-10-14');

      // Same day again (app reopened, instance deleted meanwhile): nothing.
      final after = data.withRecurring(first.templates.single).withPeriods([
        PeriodDoc.empty(Day(wed)),
      ]);
      expect(
        generateRecurringTasks(after, wed.add(const Duration(hours: 5))).docs,
        isEmpty,
      );
    });

    test('a new daily instance drops unfinished older ones', () {
      final data = const AppData()
          .withRecurring(template(const RepeatRule.daily(), last: '2026-10-13'))
          .withPeriods([
            PeriodDoc(
              period: Day(DateTime(2026, 10, 13)),
              tasks: [
                Task(
                  id: 't_old',
                  title: 'Clean room',
                  recurring: 'r_1',
                  created: wed,
                ),
              ],
            ),
          ]);
      final docs = {
        for (final d in generateRecurringTasks(data, wed).docs) d.period.key: d,
      };
      expect(docs['2026-10-13']!.tasks.single.droppedAt, wed);
      expect(docs['2026-10-14']!.tasks.single.recurring, 'r_1');
    });

    test('an open instance that rolled over blocks a duplicate', () {
      final data = const AppData()
          .withRecurring(template(const RepeatRule.daily(), last: '2026-10-13'))
          .withPeriods([
            PeriodDoc(
              period: Day(wed),
              tasks: [
                Task(
                  id: 't_old',
                  title: 'Clean room',
                  recurring: 'r_1',
                  created: wed,
                  rolledOver: 1,
                ),
              ],
            ),
          ]);
      final result = generateRecurringTasks(data, wed);
      expect(result.docs, isEmpty);
      expect(result.templates.single.lastGenerated, '2026-10-14');
    });

    test('a completed instance does not block the next one', () {
      final data = const AppData()
          .withRecurring(template(const RepeatRule.weekly(), last: '2026-W41'))
          .withPeriods([
            PeriodDoc(
              period: const Week(2026, 42),
              tasks: [
                Task(
                  id: 't_done',
                  title: 'Clean room',
                  recurring: 'r_1',
                  created: wed,
                  doneAt: wed,
                ),
              ],
            ),
          ]);
      final doc = generateRecurringTasks(data, wed).docs.single;
      expect(doc.period, const Week(2026, 42));
      expect(doc.tasks, hasLength(2));
      expect(doc.tasks.last.reminder, isNull, reason: 'weekly list: no time');
    });

    test('rules that do not fire today create nothing', () {
      final data = const AppData().withRecurring(
        template(const RepeatRule.weekdays({7})),
      );
      expect(generateRecurringTasks(data, wed).docs, isEmpty);
      expect(generateRecurringTasks(data, sun).docs.single.tasks, hasLength(1));
    });
  });

  test('reminderPlan lists open tasks with future reminders', () {
    final data = const AppData().withPeriods([
      PeriodDoc(
        period: Day(wed),
        tasks: [
          Task(
            id: 't_future',
            title: 'A',
            created: wed,
            reminder: DateTime(2026, 10, 14, 19),
          ),
          Task(
            id: 't_past',
            title: 'B',
            created: wed,
            reminder: DateTime(2026, 10, 14, 6),
          ),
          Task(
            id: 't_done',
            title: 'C',
            created: wed,
            reminder: DateTime(2026, 10, 14, 20),
            doneAt: wed,
          ),
        ],
      ),
    ]);
    expect(reminderPlan(data, wed).keys, ['t_future']);
  });

  test('template files round-trip, including weekdays and a reminder', () {
    final t = RecurringTemplate(
      id: 'r_1',
      title: 'Gym',
      priority: 1,
      rule: const RepeatRule.weekdays({5, 1, 3}),
      reminderMinute: 18 * 60 + 30,
      created: DateTime(2026, 10, 1, 9),
      lastGenerated: '2026-10-14',
    );
    final text = encodeRecurring(t);
    expect(text, contains('rule:\n  every: weekdays\n  days: [1, 3, 5]\n'));
    expect(text, contains('reminder: 18:30\n'));
    final back = decodeRecurring('x', text);
    expect(back.rule.weekdays, {1, 3, 5});
    expect(back.reminderMinute, 18 * 60 + 30);
    expect(encodeRecurring(back), text);
  });
}
