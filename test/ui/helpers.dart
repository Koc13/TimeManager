import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/storage/data_store.dart';
import 'package:time_manager/ui/app_shell.dart';
import 'package:time_manager/ui/theme/nocturne.dart';
import 'package:time_manager/ui/theme/widgets.dart';

/// File IO in widget tests is real, but its continuations run in the
/// test's fake-async zone: each IO step (mkdir, write, rename) needs a real
/// wait *and* a pump before the next one starts. Alternate both a few times.
Future<void> settleIo(WidgetTester tester, {bool settle = true}) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  if (settle) await tester.pumpAndSettle();
}

/// The app shell on [store], with "now" pinned to [now].
///
/// Pass [clock] instead when the test moves time forward.
Future<void> pumpApp(
  WidgetTester tester,
  DataStore store,
  DateTime now, {
  DateTime Function()? clock,
  List overrides = const [],
}) async {
  // A phone-sized screen, like the design's 390 × 844 frame.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(clock ?? () => now),
        ...overrides,
      ],
      child: MaterialApp(theme: nocturneTheme(), home: const AppShell()),
    ),
  );
  await settleIo(tester);
}

Future<void> openSection(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// The checkbox in the row showing [title].
Finder checkboxOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(Row)).last,
  matching: find.byType(NocCheckbox),
);

/// The visible page's vertical scroll view.
Finder get pageScroll => find
    .descendant(of: find.byType(PageView), matching: find.byType(Scrollable))
    .first;
