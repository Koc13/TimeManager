import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/task.dart';
import 'package:time_manager/storage/data_store.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  late DataStore store;
  final now = DateTime(2026, 10, 14, 9);
  const todayFile = 'periods/2026/10/2026-10-14.md';

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_ui');
    store = await DataStore.open(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> seed(WidgetTester tester, Period period, List<Task> tasks) =>
      tester.runAsync(
        () => store.savePeriods([PeriodDoc(period: period, tasks: tasks)]),
      );

  testWidgets('add a task, check it off (with Undo), and it is on disk', (
    tester,
  ) async {
    await pumpApp(tester, store, now);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('14 October 2026'), findsOneWidget);
    expect(find.text('A clear page.'), findsOneWidget);

    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    expect(find.text('New task · Today'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing?'),
      'Throw trash out',
    );
    await tester.tap(find.text('High'));
    await tester.pump();
    await tester.tap(find.text('Add task'));
    await settleIo(tester);

    expect(find.text('Throw trash out'), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
    final text = File('${dir.path}/$todayFile').readAsStringSync();
    expect(text, contains('title: Throw trash out\n'));
    expect(text, contains('priority: 1\n'));

    await tester.tap(checkboxOf('Throw trash out'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(
      File('${dir.path}/$todayFile').readAsStringSync(),
      contains('done_at: 2026-10-14T09:00:00'),
    );
    await tester.tap(find.text('Undo'));
    await settleIo(tester, settle: false);
    expect(store.data.period(Day(now)).tasks.single.isDone, isFalse);
  });

  testWidgets('leftovers are offered, kept or discarded; arrows and swipes', (
    tester,
  ) async {
    await seed(tester, Day(DateTime(2026, 10, 13)), [
      Task(id: 't_keep', title: 'Old task', created: now),
      Task(id: 't_drop', title: 'Stale task', created: now),
    ]);
    await pumpApp(tester, store, now);
    expect(find.text('UNFINISHED FROM BEFORE'), findsOneWidget);

    Finder button(String row, String label) => find.descendant(
      of: find.ancestor(of: find.text(row), matching: find.byType(Row)).first,
      matching: find.text(label),
    );
    await tester.tap(button('Old task', 'Keep'));
    await settleIo(tester, settle: false);
    await tester.tap(button('Stale task', 'Discard'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('UNFINISHED FROM BEFORE'), findsNothing);
    expect(find.text('Old task'), findsOneWidget); // now in today's list
    expect(find.textContaining('Carried +1'), findsOneWidget);
    final yesterday = store.data.period(Day(DateTime(2026, 10, 13)));
    expect(yesterday.tasks.single.droppedAt, now, reason: 'kept as history');

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    // Planning tomorrow: today's open task is offered.
    expect(find.text('STILL OPEN TODAY'), findsOneWidget);
    await tester.tap(find.text('← Back to today'));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Week 42'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('October'), findsOneWidget);
  });

  testWidgets('the action sheet postpones a task to tomorrow', (tester) async {
    await seed(tester, Day(now), [
      Task(id: 't_1', title: 'Call bank', created: now),
    ]);
    await pumpApp(tester, store, now);
    await tester.tap(find.text('Call bank'));
    await tester.pumpAndSettle();
    expect(find.text('In Today'), findsOneWidget);
    await tester.tap(find.text('Postpone to tomorrow'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Call bank'), findsNothing);
    final moved = store.data.period(Day(now).next).tasks.single;
    expect((moved.title, moved.rolledOver), ('Call bank', 1));
  });

  testWidgets('move a task from the day list to this week', (tester) async {
    await seed(tester, Day(now), [
      Task(id: 't_1', title: 'Plan trip', created: now),
    ]);
    await pumpApp(tester, store, now);
    await tester.tap(find.text('Plan trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to this week'));
    await settleIo(tester);
    expect(find.text('Plan trip'), findsNothing);

    await tester.tap(find.text('Week'));
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
    await pumpApp(tester, store, now);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Your files, in plain Markdown.'), findsOneWidget);
    expect(find.text('0 open today'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('No active goals.'), findsOneWidget);
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
    await pumpApp(tester, store, now);

    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await back();
    expect(find.text('Your files, in plain Markdown.'), findsNothing);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await openSection(tester, 'Habits');
    expect(find.text('No habits yet.'), findsOneWidget);
    await back();
    expect(find.text('Wednesday'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await back();
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('done tasks show below the list and can be unchecked', (
    tester,
  ) async {
    await seed(tester, const Week(2026, 42), [
      Task(id: 't_1', title: 'Weekly chore', created: now, doneAt: now),
    ]);
    await pumpApp(tester, store, now);
    // Completed on Wednesday in the weekly list: shows on today's page too.
    await tester.scrollUntilVisible(
      find.text('from Week 42'),
      200,
      scrollable: pageScroll,
    );
    expect(find.text('Weekly chore'), findsOneWidget);

    await tester.tap(checkboxOf('Weekly chore'));
    await settleIo(tester);
    expect(find.text('Weekly chore'), findsNothing);
    expect(
      store.data.period(const Week(2026, 42)).tasks.single.isDone,
      isFalse,
    );
  });

  testWidgets('the journal saves into the file body', (tester) async {
    await pumpApp(tester, store, now);
    final journal = find.widgetWithText(TextField, 'How did the day go?');
    await tester.scrollUntilVisible(journal, 200, scrollable: pageScroll);
    expect(find.text('Saves as you type'), findsOneWidget);
    await tester.enterText(journal, 'Good day.\n\n- shipped the pager');
    await tester.pump(const Duration(seconds: 1)); // debounce
    await settleIo(tester);
    final text = File('${dir.path}/$todayFile').readAsStringSync();
    expect(text, endsWith('---\nGood day.\n\n- shipped the pager'));
    expect(find.textContaining('Saved '), findsOneWidget);

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('shipped the pager'), findsOneWidget);
  });

  testWidgets('a repeating task creates a template and today\'s instance', (
    tester,
  ) async {
    await pumpApp(tester, store, now);
    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What needs doing?'),
      'Stretch',
    );
    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day'));
    await tester.pumpAndSettle();
    expect(find.text('↻ Daily'), findsOneWidget); // the chip now says so
    await tester.tap(find.text('Add task'));
    await settleIo(tester);

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.textContaining('↻ Daily'), findsOneWidget); // meta line
    expect(store.data.recurring.values.single.lastGenerated, '2026-10-14');

    // Stopping the series keeps today's task.
    await tester.tap(find.text('Stretch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop repeating'));
    await settleIo(tester);
    expect(store.data.recurring, isEmpty);
    expect(find.text('Stretch'), findsOneWidget);
  });

  testWidgets('deadlines show as due, and overdue in the accent', (
    tester,
  ) async {
    await seed(tester, Day(now), [
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
        deadline: DateTime(2026, 10, 16, 17),
        priority: 3,
      ),
    ]);
    await pumpApp(tester, store, now);
    expect(find.text('Due today · Overdue'), findsOneWidget);
    expect(find.text('Due Fri 16 Oct'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
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
    await pumpApp(tester, store, now);
    expect(find.text('1 sync conflict in your data folder'), findsOneWidget);
    await tester.tap(find.text('1 sync conflict in your data folder'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('2026-10-14.sync-conflict-20261014-1.md'),
      findsOneWidget,
    );
  });
}
