import 'dart:io';

import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/task.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/storage/data_store.dart';
import 'package:time_manager/ui/app_shell.dart';
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

  testWidgets('leftovers are offered, kept or discarded; arrows and swipes', (
    tester,
  ) async {
    await tester.runAsync(
      () => store.savePeriods([
        PeriodDoc(
          period: Day(DateTime(2026, 10, 13)),
          tasks: [
            Task(id: 't_keep', title: 'Old task', created: now),
            Task(id: 't_drop', title: 'Stale task', created: now),
          ],
        ),
      ]),
    );
    await pumpApp(tester);
    expect(find.text('Unfinished from before (2)'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Old task'),
        matching: find.byTooltip('Keep'),
      ),
    );
    await settleIo(tester);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Stale task'),
        matching: find.byTooltip('Discard'),
      ),
    );
    await settleIo(tester);
    expect(find.text('Unfinished from before (2)'), findsNothing);
    expect(find.text('Old task'), findsOneWidget); // now in today's list
    expect(find.textContaining('↻ 1'), findsOneWidget);
    final yesterday = store.data.period(Day(DateTime(2026, 10, 13)));
    expect(yesterday.tasks.single.droppedAt, now, reason: 'kept as history');

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Thu 15 Oct'), findsOneWidget);
    // Planning tomorrow: today's open task is offered.
    expect(find.text('Still open today (1)'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Week 42'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('postpone moves a task to tomorrow', (tester) async {
    await tester.runAsync(
      () => store.savePeriods([
        PeriodDoc(
          period: Day(now),
          tasks: [Task(id: 't_1', title: 'Call bank', created: now)],
        ),
      ]),
    );
    await pumpApp(tester);
    await tester.longPress(find.text('Call bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Postpone to Thu 15 Oct'));
    await settleIo(tester);
    expect(find.text('Call bank'), findsNothing);
    final moved = store.data.period(Day(now).next).tasks.single;
    expect((moved.title, moved.rolledOver), ('Call bank', 1));
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
    expect(find.text('No active goals'), findsOneWidget);
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
    expect(find.text('No habits yet'), findsOneWidget);
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

  testWidgets('a repeating task creates a template and today\'s instance', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Stretch');
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day'));
    await tester.pumpAndSettle();
    expect(find.text('Every day'), findsOneWidget); // the chip now says so
    await tester.tap(find.text('Save'));
    await settleIo(tester);

    expect(find.text('Stretch'), findsOneWidget);
    final template = store.data.recurring.values.single;
    expect(template.lastGenerated, '2026-10-14');
    expect(Directory('${dir.path}/recurring').listSync(), hasLength(1));

    // Stopping the series keeps today's task.
    await tester.longPress(find.text('Stretch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop repeating'));
    await settleIo(tester);
    expect(store.data.recurring, isEmpty);
    expect(find.text('Stretch'), findsOneWidget);
  });

  testWidgets('overdue deadlines are highlighted', (tester) async {
    await tester.runAsync(
      () => store.savePeriods([
        PeriodDoc(
          period: Day(now),
          tasks: [
            Task(
              id: 't_1',
              title: 'Send form',
              created: now,
              deadline: DateTime(2026, 10, 14, 8),
            ),
            Task(
              id: 't_2',
              title: 'Call bank',
              created: now,
              deadline: DateTime(2026, 10, 14, 17),
            ),
          ],
        ),
      ]),
    );
    await pumpApp(tester);
    expect(find.text('Overdue · Wed 14 Oct 08:00'), findsOneWidget);
    expect(find.text('Due Wed 14 Oct 17:00'), findsOneWidget);
  });

  testWidgets('a Syncthing conflict copy shows a warning banner', (
    tester,
  ) async {
    await tester.runAsync(() async {
      Directory('${dir.path}/periods/2026/10').createSync(recursive: true);
      File('${dir.path}/periods/2026/10/2026-10-14.sync-conflict-20261014-1.md')
          .writeAsStringSync('---\n---\n');
      await store.reload();
    });
    await pumpApp(tester);
    expect(find.text('1 sync conflict in your data folder'), findsOneWidget);
    await tester.tap(find.text('1 sync conflict in your data folder'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('2026-10-14.sync-conflict-20261014-1.md'),
      findsOneWidget,
    );
  });
}
