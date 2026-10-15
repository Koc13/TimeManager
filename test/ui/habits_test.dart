import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/goal.dart';
import 'package:time_manager/domain/habit.dart';
import 'package:time_manager/storage/data_store.dart';
import 'package:time_manager/ui/theme/icons.dart';
import 'package:time_manager/ui/theme/widgets.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  late DataStore store;
  final now = DateTime(2026, 10, 14, 9); // Wednesday of W42
  const todayFile = 'periods/2026/10/2026-10-14.md';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_habits');
    store = await DataStore.open(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  Finder cell(String label) =>
      find.byWidgetPredicate((w) => w is HeatCell && w.semanticLabel == label);

  testWidgets('create a yes/no habit and check today', (tester) async {
    await pumpApp(tester, store, now);
    await openSection(tester, 'Habits');
    expect(find.text('Week 42'), findsOneWidget);
    expect(find.text('12 Oct – 18 Oct'), findsOneWidget);

    await tester.tap(find.text('Add a habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Habit'), 'Gym');
    await tester.tap(find.text('Save'));
    await settleIo(tester);

    await tester.tap(cell('Gym Wed'));
    await settleIo(tester);
    expect(find.byIcon(Ph.check), findsOneWidget);
    expect(find.text('1 of 7'), findsOneWidget);
    expect(
      File('${dir.path}/$todayFile').readAsStringSync(),
      contains('value: true\n'),
    );

    // Tapping again unchecks (removes the entry).
    await tester.tap(cell('Gym Wed'));
    await settleIo(tester);
    expect(find.byIcon(Ph.check), findsNothing);
  });

  testWidgets('a measurable entry is shaded and completes its linked goal', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await store.saveGoal(
        Goal(
          id: 'g_book',
          title: 'Finish book',
          target: 30,
          unit: 'pages',
          created: now,
        ),
      );
      await store.saveHabit(
        Habit(
          id: 'h_read',
          title: 'Reading',
          kind: HabitKind.measurable,
          unit: 'pages',
          goal: 'g_book',
          created: now,
        ),
      );
    });
    await pumpApp(tester, store, now);
    await openSection(tester, 'Habits');

    await tester.tap(cell('Reading Wed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '30');
    await tester.tap(find.text('Save'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    final heat = tester.widget<HeatCell>(cell('Reading Wed'));
    expect((heat.level, heat.label), (4, '30'));
    expect(find.text('30 pages'), findsOneWidget); // weekly total
    expect(store.data.goals['g_book']!.status, GoalStatus.completed);
    expect(find.text('Completed: Finish book'), findsOneWidget);
  });

  testWidgets('future days cannot be logged', (tester) async {
    await tester.runAsync(
      () => store.saveHabit(Habit(id: 'h_gym', title: 'Gym', created: now)),
    );
    await pumpApp(tester, store, now);
    await openSection(tester, 'Habits');
    expect(tester.widget<HeatCell>(cell('Gym Thu')).enabled, isFalse);
    await tester.tap(cell('Gym Thu'), warnIfMissed: false);
    await settleIo(tester);
    expect(find.byIcon(Ph.check), findsNothing);
  });

  test('levelFor scales a value against the target into 1–4', () {
    expect(levelFor(0, 20), 0);
    expect(levelFor(1, 20), 1);
    expect(levelFor(10, 20), 2);
    expect(levelFor(15, 20), 3);
    expect(levelFor(20, 20), 4);
    expect(levelFor(45, 20), 4);
  });
}
