// Renders the store screenshots from a demo data folder.
//
//   flutter test tool/screenshots/store_screenshots_test.dart
//
// Writes fastlane/metadata/android/en-US/images/phoneScreenshots/*.png.
// It lives outside test/ so a plain `flutter test` doesn't rewrite them.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/activity.dart';
import 'package:time_manager/domain/goal.dart';
import 'package:time_manager/domain/habit.dart';
import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/target_ref.dart';
import 'package:time_manager/domain/task.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/storage/data_store.dart';
import 'package:time_manager/ui/app_shell.dart';
import 'package:time_manager/ui/theme/nocturne.dart';

import '../../test/ui/helpers.dart';

const outDir = 'fastlane/metadata/android/en-US/images/phoneScreenshots';
final now = DateTime(2026, 10, 14, 9, 30); // a Wednesday

void main() {
  late Directory dir;
  late DataStore store;

  setUpAll(loadFonts);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_demo');
    store = await DataStore.open(dir.path);
  });
  tearDown(() => dir.delete(recursive: true));

  testWidgets('store screenshots', (tester) async {
    await tester.runAsync(() => seed(store));
    await pumpPhone(tester, store);
    await shoot(tester, '1_todo');

    await openSection(tester, 'Goals');
    await shoot(tester, '2_goals');

    await openSection(tester, 'Habits');
    await shoot(tester, '3_habits');

    await openSection(tester, 'Timer');
    await shoot(tester, '4_timer');
  });
}

/// Widget tests render text in the "Ahem" box font unless real fonts are
/// loaded; the bundled ones are pubspec assets, so the test bundle has them.
Future<void> loadFonts() async {
  final fonts = {
    'Inter': ['Inter-Regular.ttf', 'Inter-Medium.ttf'],
    'Phosphor': ['Phosphor.ttf'],
    'PhosphorBold': ['Phosphor-Bold.ttf'],
  };
  for (final MapEntry(key: family, value: files) in fonts.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }
}

/// A 1080 × 2340 phone (393 × 852 logical at 2.75×, like a Pixel 8).
Future<void> pumpPhone(WidgetTester tester, DataStore store) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      child: ProviderScope(
        overrides: [
          dataStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: nocturneTheme(),
          home: const AppShell(),
        ),
      ),
    ),
  );
  await settleIo(tester);
}

Future<void> shoot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.75);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
}

/// A believable couple of weeks: goals with logged progress, habits with a
/// partly filled week, and today's list half done.
Future<void> seed(DataStore store) async {
  final created = now.subtract(const Duration(days: 40));
  final goals = [
    Goal(
      id: 'g_thesis',
      title: 'Master thesis',
      target: 60,
      unit: 'pages',
      created: created,
    ),
    Goal(
      id: 'g_lc',
      title: 'LeetCode',
      target: 150,
      unit: 'problems',
      parent: 'g_interview',
      created: created,
    ),
    Goal(
      id: 'g_interview',
      title: 'Interview prep',
      kind: GoalKind.log,
      created: created,
    ),
    Goal(
      id: 'g_sys',
      title: 'System design',
      target: 20,
      unit: 'hours',
      parent: 'g_interview',
      created: created,
    ),
    Goal(
      id: 'g_read',
      title: 'Read 12 books',
      target: 12,
      unit: 'books',
      created: created,
    ),
    Goal(
      id: 'g_run',
      title: 'Run a half marathon',
      kind: GoalKind.log,
      created: created,
    ),
  ];
  for (final g in goals) {
    await store.saveGoal(g);
  }
  final habits = [
    Habit(id: 'h_gym', title: 'Gym', created: created),
    Habit(
      id: 'h_read',
      title: 'Reading',
      kind: HabitKind.measurable,
      unit: 'pages',
      created: created,
    ),
    Habit(
      id: 'h_focus',
      title: 'Deep work',
      kind: HabitKind.measurable,
      unit: 'min',
      created: created,
    ),
    Habit(id: 'h_journal', title: 'Journal', created: created),
  ];
  for (final h in habits) {
    await store.saveHabit(h);
  }

  final docs = <PeriodDoc>[];
  var n = 0;
  String id(String p) => '${p}_${n++}';
  // Ten earlier days, finished, so no leftovers are offered for review.
  for (var back = 10; back >= 1; back--) {
    final date = DateTime(now.year, now.month, now.day - back, 18);
    docs.add(
      PeriodDoc(
        period: Day(date),
        tasks: [
          Task(id: id('t'), title: 'Inbox zero', created: date, doneAt: date),
        ],
        habitEntries: [
          if (back % 3 != 0) const HabitEntry(habit: 'h_gym', value: true),
          HabitEntry(habit: 'h_read', value: 10 + (back * 7) % 25),
          HabitEntry(habit: 'h_focus', value: 45 + (back * 23) % 90),
          if (back.isEven) const HabitEntry(habit: 'h_journal', value: true),
        ],
        goalLogs: [
          GoalLog(
            id: id('l'),
            goal: 'g_thesis',
            amount: 2 + back % 3,
            at: date,
          ),
          GoalLog(id: id('l'), goal: 'g_lc', amount: 3 + back % 4, at: date),
          if (back % 4 == 0)
            GoalLog(id: id('l'), goal: 'g_read', amount: 1, at: date),
          if (back % 3 == 0)
            GoalLog(
              id: id('l'),
              goal: 'g_run',
              amount: 8,
              unit: 'km',
              source: 'Long run',
              at: date,
            ),
          if (back.isOdd)
            GoalLog(id: id('l'), goal: 'g_sys', amount: 1.5, at: date),
        ],
        journal: back == 1 ? 'Good focus in the morning, slow afternoon.' : '',
      ),
    );
  }

  DateTime at(int h, [int m = 0]) =>
      DateTime(now.year, now.month, now.day, h, m);
  docs.add(
    PeriodDoc(
      period: Day(now),
      tasks: [
        Task(
          id: 'td1',
          title: 'Write the related-work section',
          priority: 1,
          link: const TargetRef.goal('g_thesis'),
          created: at(7),
        ),
        Task(
          id: 'td2',
          title: 'Two medium LeetCode problems',
          link: const TargetRef.goal('g_lc'),
          created: at(7),
        ),
        Task(
          id: 'td3',
          title: 'Email the supervisor',
          priority: 1,
          deadline: at(17),
          created: at(7),
        ),
        Task(
          id: 'td4',
          title: 'Take out the trash',
          priority: 3,
          created: at(7),
        ),
        Task(
          id: 'td5',
          title: 'Morning run',
          created: at(7),
          doneAt: at(7, 40),
        ),
        Task(id: 'td6', title: 'Plan the day', created: at(7), doneAt: at(8)),
      ],
      sessions: [
        Session(
          id: 's1',
          target: const TargetRef.goal('g_thesis'),
          start: at(8, 10),
          plannedMin: 50,
          actualMin: 50,
        ),
      ],
      habitEntries: const [HabitEntry(habit: 'h_gym', value: true)],
    ),
  );
  docs.add(
    PeriodDoc(
      period: Week.containing(now),
      tasks: [
        Task(
          id: 'tw1',
          title: 'Finish chapter 2 draft',
          priority: 1,
          created: created,
        ),
        Task(id: 'tw2', title: 'Book the dentist', created: created),
      ],
    ),
  );
  await store.savePeriods(docs);
}
