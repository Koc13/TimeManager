import 'package:first_app/domain/activity.dart';
import 'package:first_app/domain/goal.dart';
import 'package:first_app/domain/habit.dart';
import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/period_doc.dart';
import 'package:first_app/domain/target_ref.dart';
import 'package:first_app/domain/task.dart';
import 'package:first_app/storage/codecs.dart';
import 'package:flutter_test/flutter_test.dart';

/// ISO time with this machine's offset, so the fixtures pass in any zone.
String iso(int day, int h, int m) {
  final t = DateTime(2026, 10, day, h, m);
  final o = t.timeZoneOffset;
  String two(int n) => n.abs().toString().padLeft(2, '0');
  return '2026-10-${two(day)}T${two(h)}:${two(m)}:00'
      '${o.isNegative ? '-' : '+'}${two(o.inHours)}:${two(o.inMinutes % 60)}';
}

void main() {
  final day = Day(DateTime(2026, 10, 14));

  // An example day file in canonical form, plus unknown keys at the
  // top level, inside a task, and inside a session.
  final dayFile =
      '''
---
date: 2026-10-14
tasks:
  - id: t_3fq8kz2m
    title: Throw trash out
    priority: 2
    deadline: ${iso(14, 20, 0)}
    reminder: ${iso(14, 19, 0)}
    link: {type: habit, id: h_2m8d0qwe}
    recurring: null
    rolled_over: 0
    created: ${iso(14, 8, 10)}
    done_at: ${iso(14, 18, 32)}
    dropped_at: null
    color: red
sessions:
  - id: s_9xk1p0aa
    target: {type: goal, id: g_7k2m9xqa}
    start: ${iso(14, 9, 0)}
    planned_min: 50
    actual_min: 50
    mood: 4
  - id: s_custom01
    target: {type: custom, name: Tax forms}
    start: ${iso(14, 11, 0)}
    planned_min: 25
    actual_min: 20
habit_entries:
  - habit: h_2m8d0qwe
    value: true
  - habit: h_reading1
    value: 30
goal_logs:
  - id: l_5tq0zz81
    goal: g_1b4c8nnm
    amount: 25
    unit: pages
    source: Pattern Recognition (Bishop)
    at: ${iso(14, 21, 15)}
weather: sunny
---
# Journal

Free Markdown text.
''';

  test('day file: write(parse(file)) is byte-identical', () {
    expect(encodePeriodDoc(decodePeriodDoc(day, dayFile)), dayFile);
  });

  test('day file: fields are parsed into the right types', () {
    final doc = decodePeriodDoc(day, dayFile);
    final task = doc.tasks.single;
    expect(task.title, 'Throw trash out');
    expect(task.deadline, DateTime(2026, 10, 14, 20));
    expect(task.link, const TargetRef.habit('h_2m8d0qwe'));
    expect(task.isDone, isTrue);
    expect(task.extra, {'color': 'red'});
    expect(doc.sessions[1].target, const TargetRef.custom('Tax forms'));
    expect(doc.habitEntries.map((e) => e.value), [true, 30]);
    expect(doc.goalLogs.single.source, 'Pattern Recognition (Bishop)');
    expect(doc.extra, {'weather': 'sunny'});
    expect(doc.journal, '# Journal\n\nFree Markdown text.\n');
  });

  test('editing a known field keeps unknown ones', () {
    final doc = decodePeriodDoc(day, dayFile);
    final edited = doc.copyWith(
      tasks: [doc.tasks.single.copyWith(title: 'Trash', doneAt: null)],
    );
    final text = encodePeriodDoc(edited);
    expect(text, contains('title: Trash\n'));
    expect(text, contains('done_at: null\n'));
    expect(text, contains('color: red\n'));
    expect(text, contains('mood: 4\n'));
    expect(text, contains('weather: sunny\n'));
  });

  test('week and month files hold only tasks and the journal', () {
    final week = PeriodDoc(
      period: const Week(2026, 42),
      tasks: [
        Task(id: 't_1', title: 'Plan trip', created: DateTime(2026, 10, 12)),
      ],
      journal: 'Review notes\n',
    );
    final text = encodePeriodDoc(week);
    expect(text, startsWith('---\nweek: 2026-W42\ntasks:\n  - id: t_1\n'));
    expect(text, isNot(contains('sessions')));
    expect(encodePeriodDoc(decodePeriodDoc(week.period, text)), text);
  });

  test('a plain string task typed by hand becomes a task', () {
    final doc = decodePeriodDoc(day, '---\ntasks:\n  - Buy milk\n---\n');
    expect(doc.tasks.single.title, 'Buy milk');
    expect(doc.tasks.single.id, startsWith('t_'));
  });

  test('an unreadable entry fails the whole file instead of dropping it', () {
    expect(
      () => decodePeriodDoc(day, '---\nsessions:\n  - nonsense\n---\n'),
      throwsFormatException,
    );
    expect(
      () => decodePeriodDoc(day, '---\ngoal_logs:\n  - {goal: g_1}\n---\n'),
      throwsFormatException,
    );
  });

  test('goal file round-trips, notes and unknown keys included', () {
    final goalFile =
        '''
---
id: g_7k2m9xqa
title: 100 LeetCode problems
kind: measurable
target: 100
unit: problems
parent: g_0a1interv
status: on_hold
created: ${iso(14, 19, 20)}
completed: null
tags: [interview]
---
Optional notes.
''';
    final goal = decodeGoal('ignored', goalFile);
    expect(goal.status, GoalStatus.onHold);
    expect(goal.target, 100);
    expect(goal.extra, {
      'tags': ['interview'],
    });
    expect(encodeGoal(goal), goalFile);
  });

  test('habit file round-trips', () {
    final habit = Habit(
      id: 'h_reading1',
      title: 'Reading',
      kind: HabitKind.measurable,
      unit: 'pages',
      goal: 'g_norwood1',
      created: DateTime(2026, 10, 1, 7),
      notes: 'Before bed.\n',
    );
    final text = encodeHabit(habit);
    expect(text, contains('kind: measurable\n'));
    expect(text, contains('goal_amount: 1\n'));
    expect(encodeHabit(decodeHabit('x', text)), text);
  });

  test('a goal file without an id takes it from the file name', () {
    expect(decodeGoal('g_fromname', '---\ntitle: X\n---\n').id, 'g_fromname');
  });

  test('a session/log round-trip through PeriodDoc keeps every value', () {
    final doc = PeriodDoc(
      period: day,
      goalLogs: [
        GoalLog(
          id: 'l_1',
          goal: 'g_1',
          amount: 2.5,
          source: 'Course: part 1',
          at: DateTime(2026, 10, 14, 10),
        ),
      ],
    );
    final back = decodePeriodDoc(day, encodePeriodDoc(doc)).goalLogs.single;
    expect(back.amount, 2.5);
    expect(back.source, 'Course: part 1');
    expect(back.at, DateTime(2026, 10, 14, 10));
  });
}
