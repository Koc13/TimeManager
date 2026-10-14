import 'dart:io';

import 'package:first_app/providers/data_providers.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:first_app/ui/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late DataStore store;
  late DateTime now;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_timer_ui');
    store = await DataStore.open(dir.path);
    now = DateTime(2026, 10, 14, 9);
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  testWidgets('pick a custom topic, run, stop early and keep it', (
    tester,
  ) async {
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
    await tester.tap(find.text('Timer'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions yet'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tax forms');
    await tester.pump();
    await tester.tap(find.text('Custom session: "Tax forms"'));
    await tester.pump();
    await tester.tap(find.text('50 min'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    await settleIo(tester);
    expect(find.text('50:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 7, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('42:55'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await settleIo(tester);
    expect(find.text('Keep this 7 min session?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await settleIo(tester);

    expect(find.text('Tax forms'), findsOneWidget); // today's totals
    expect(find.text('7 min · 1 session'), findsOneWidget);
    expect(
      File('${dir.path}/periods/2026/10/2026-10-14.md').readAsStringSync(),
      contains('target: {type: custom, name: Tax forms}'),
    );
  });
}
