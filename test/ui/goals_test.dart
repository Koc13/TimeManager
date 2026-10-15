import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/goal.dart';
import 'package:time_manager/storage/data_store.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  late DataStore store;
  final now = DateTime(2026, 10, 14, 9);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_goals');
    store = await DataStore.open(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  testWidgets('create a measurable goal, log past its target, undo', (
    tester,
  ) async {
    await pumpApp(tester, store, now);
    await openSection(tester, 'Goals');
    await tester.tap(find.text('Add a goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Goal'), 'LeetCode');
    await tester.enterText(find.widgetWithText(TextField, 'Target'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Unit'), 'problems');
    await tester.tap(find.text('Save'));
    await settleIo(tester);
    expect(find.text('0 of 10 problems'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(Directory('${dir.path}/goals').listSync(), hasLength(1));

    await tester.tap(find.text('LeetCode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log progress'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '10');
    await tester.tap(find.text('Log'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.data.goals.values.single.status, GoalStatus.completed);
    expect(find.text('Completed: LeetCode'), findsOneWidget);
    expect(
      File('${dir.path}/periods/2026/10/2026-10-14.md').readAsStringSync(),
      contains('amount: 10\n'),
    );

    await tester.tap(find.text('Undo'));
    await settleIo(tester, settle: false);
    expect(store.data.goals.values.single.status, GoalStatus.active);
  });

  testWidgets('sub-goals are indented; on hold is collapsed', (tester) async {
    await tester.runAsync(() async {
      await store.saveGoal(
        Goal(
          id: 'g_p',
          title: 'Interview prep',
          kind: GoalKind.log,
          created: now,
        ),
      );
      await store.saveGoal(
        Goal(
          id: 'g_c',
          title: 'Kaggle',
          target: 100,
          parent: 'g_p',
          created: now,
        ),
      );
      await store.saveGoal(
        Goal(
          id: 'g_h',
          title: 'Someday',
          kind: GoalKind.log,
          status: GoalStatus.onHold,
          created: now,
        ),
      );
    });
    await pumpApp(tester, store, now);
    await openSection(tester, 'Goals');

    expect(find.text('ACTIVE · 1'), findsOneWidget);
    expect(find.text('0 of 1 sub-goal complete'), findsOneWidget);
    final parentX = tester.getTopLeft(find.text('Interview prep')).dx;
    final childX = tester.getTopLeft(find.text('Kaggle')).dx;
    expect(childX - parentX, 18);
    expect(find.text('Someday'), findsNothing);
    await tester.tap(find.text('ON HOLD · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Someday'), findsOneWidget);
  });
}
