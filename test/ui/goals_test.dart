import 'dart:io';

import 'package:first_app/domain/goal.dart';
import 'package:first_app/providers/data_providers.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:first_app/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DataStore store;
  final now = DateTime(2026, 10, 14, 9);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_goals');
    store = await DataStore.open(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> openGoals(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await settleIo(tester);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
  }

  testWidgets('create a measurable goal, log past its target, undo', (
    tester,
  ) async {
    await openGoals(tester);
    await tester.tap(find.byTooltip('Add goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Goal'), 'LeetCode');
    await tester.enterText(find.widgetWithText(TextField, 'Target'), '10');
    await tester.enterText(find.widgetWithText(TextField, 'Unit'), 'problems');
    await tester.tap(find.text('Save'));
    await settleIo(tester);
    expect(find.text('0 / 10 problems · 0%'), findsOneWidget);
    expect(Directory('${dir.path}/goals').listSync(), hasLength(1));

    await tester.tap(find.text('LeetCode'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '10');
    await tester.tap(find.widgetWithText(FilledButton, 'Log'));
    await settleIo(tester);

    final goal = store.data.goals.values.single;
    expect(goal.status, GoalStatus.completed);
    expect(find.text('Completed: LeetCode'), findsOneWidget);
    expect(
      File('${dir.path}/periods/2026/10/2026-10-14.md').readAsStringSync(),
      contains('amount: 10\n'),
    );

    await tester.tap(find.text('Undo'));
    await settleIo(tester);
    expect(store.data.goals.values.single.status, GoalStatus.active);
  });

  testWidgets('sub-goals are indented under their parent', (tester) async {
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
    await openGoals(tester);

    final parentX = tester.getTopLeft(find.text('Interview prep')).dx;
    final childX = tester.getTopLeft(find.text('Kaggle')).dx;
    expect(childX, greaterThan(parentX));
    // On hold is collapsed by default.
    expect(find.text('On hold (1)'), findsOneWidget);
    expect(find.text('Someday'), findsNothing);
    await tester.tap(find.text('On hold (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Someday'), findsOneWidget);
  });
}
