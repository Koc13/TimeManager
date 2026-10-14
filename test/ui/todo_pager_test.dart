import 'dart:io';

import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/period_doc.dart';
import 'package:first_app/domain/task.dart';
import 'package:first_app/providers/data_providers.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:first_app/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DataStore store;
  final now = DateTime(2026, 10, 14, 9);
  final todayFile = 'periods/2026/10/2026-10-14.md';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_ui');
    store = await DataStore.open(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  // File IO is real, but its continuations run in the test's fake-async
  // zone: each IO step (mkdir, write, rename) needs a real wait *and* a
  // pump before the next one starts. Alternate both a few times.
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester) async {
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
  }

  testWidgets('add a task, check it off, and it is on disk', (tester) async {
    await pumpApp(tester);
    expect(find.text('Wed 14 Oct'), findsOneWidget);
    expect(find.text('Nothing to do'), findsOneWidget);

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Throw trash out');
    await tester.tap(find.text('High'));
    await tester.tap(find.text('Save'));
    await settleIo(tester);

    expect(find.text('Throw trash out'), findsOneWidget);
    final text = File('${dir.path}/$todayFile').readAsStringSync();
    expect(text, contains('title: Throw trash out\n'));
    expect(text, contains('priority: 1\n'));

    await tester.tap(find.byType(Checkbox));
    await settleIo(tester);
    expect(find.text('Nothing to do'), findsOneWidget);
    expect(
      File('${dir.path}/$todayFile').readAsStringSync(),
      contains('done_at: 2026-10-14T09:00:00'),
    );
  });

  testWidgets('rollover on start, arrows and swipes between lists', (
    tester,
  ) async {
    await tester.runAsync(
      () => store.savePeriods([
        PeriodDoc(
          period: Day(DateTime(2026, 10, 13)),
          tasks: [Task(id: 't_old', title: 'Old task', created: now)],
        ),
      ]),
    );
    await pumpApp(tester);
    expect(find.text('Old task'), findsOneWidget);
    expect(find.textContaining('↻ 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Thu 15 Oct'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Week 42'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('move a task from the day list to the week list', (tester) async {
    await tester.runAsync(
      () => store.savePeriods([
        PeriodDoc(
          period: Day(now),
          tasks: [Task(id: 't_1', title: 'Plan trip', created: now)],
        ),
      ]),
    );
    await pumpApp(tester);
    await tester.longPress(find.text('Plan trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to weekly list'));
    await settleIo(tester);
    expect(find.text('Plan trip'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Plan trip'), findsOneWidget);
    expect(
      File('${dir.path}/periods/2026/2026-W42.md').readAsStringSync(),
      contains('title: Plan trip'),
    );
  });

  testWidgets('swiping right on the daily list opens the drawer', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDrawer), findsOneWidget);
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('Back closes the drawer, then leaves a section, then exits', (
    tester,
  ) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    await pumpApp(tester);

    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await back();
    expect(find.byType(NavigationDrawer), findsNothing);
    expect(find.text('Wed 14 Oct'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Habits'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    await back();
    expect(find.text('Wed 14 Oct'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await back();
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('checked tasks show on the Done page and can be unchecked', (
    tester,
  ) async {
    await tester.runAsync(
      () => store.savePeriods([
        PeriodDoc(
          period: const Week(2026, 42),
          tasks: [Task(id: 't_1', title: 'Weekly chore', created: now)],
        ),
      ]),
    );
    await pumpApp(tester);
    // Check it off on the weekly list.
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await settleIo(tester);

    // It shows on today's Done page, marked as coming from the week list.
    await tester.fling(find.byType(PageView), const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Weekly chore'),
      300,
      scrollable: find.byType(Scrollable).at(1),
    );
    expect(find.textContaining('from Week 42'), findsOneWidget);

    // Unchecking it on the Done page puts it back on the weekly list.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Weekly chore'),
        matching: find.byType(Checkbox),
      ),
    );
    await settleIo(tester);
    expect(find.text('Weekly chore'), findsNothing);
    expect(
      store.data.period(const Week(2026, 42)).tasks.single.isDone,
      isFalse,
    );
  });

  testWidgets('the journal saves into the file body', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      300,
      scrollable: find.byType(Scrollable).at(1),
    );
    await tester.enterText(find.byType(TextField), 'Good day.\n\n- shipped the pager');
    await tester.pump(const Duration(seconds: 1)); // debounce
    await settleIo(tester);
    final text = File('${dir.path}/$todayFile').readAsStringSync();
    expect(text, endsWith('---\nGood day.\n\n- shipped the pager'));

    await tester.tap(find.byTooltip('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('shipped the pager'), findsOneWidget);
  });
}
