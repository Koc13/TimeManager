import 'dart:io';

import 'package:time_manager/domain/goal.dart';
import 'package:time_manager/domain/habit.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/storage/data_store.dart';
import 'package:time_manager/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DataStore store;
  final now = DateTime(2026, 10, 14, 9); // Wednesday, column 3 of W42
  final todayFile = 'periods/2026/10/2026-10-14.md';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_habits');
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

  Future<void> openHabits(WidgetTester tester) async {
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
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
  }

  // The tappable cells of a habit's row, Monday first.
  Finder cells(String habit) => find.descendant(
    of: find.ancestor(of: find.text(habit), matching: find.byType(Row)).first,
    matching: find.byType(InkWell),
  );

  testWidgets('create a yes/no habit and check today', (tester) async {
    await openHabits(tester);
    expect(find.text('Week 42 · 12 Oct'), findsOneWidget);

    await tester.tap(find.byTooltip('Add habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Habit'), 'Gym');
    await tester.tap(find.text('Save'));
    await settleIo(tester);

    // cells(): [name, Mon, Tue, Wed, ...]
    await tester.tap(cells('Gym').at(3));
    await settleIo(tester);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      File('${dir.path}/$todayFile').readAsStringSync(),
      contains('value: true\n'),
    );

    // Tapping again unchecks (removes the entry).
    await tester.tap(cells('Gym').at(3));
    await settleIo(tester);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(
      store.data.period(store.data.periods.values.first.period).habitEntries,
      isEmpty,
    );
  });

  testWidgets('a measurable entry feeds and completes its linked goal', (
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
    await openHabits(tester);

    await tester.tap(cells('Reading').at(3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '30');
    await tester.tap(find.text('Save'));
    await settleIo(tester);

    expect(find.text('30'), findsOneWidget);
    expect(store.data.goals['g_book']!.status, GoalStatus.completed);
    expect(find.text('Completed: Finish book'), findsOneWidget);
  });

  testWidgets('future days cannot be logged', (tester) async {
    await tester.runAsync(
      () => store.saveHabit(Habit(id: 'h_gym', title: 'Gym', created: now)),
    );
    await openHabits(tester);
    await tester.tap(cells('Gym').at(4)); // Thursday
    await settleIo(tester);
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
