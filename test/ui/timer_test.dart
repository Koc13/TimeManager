import 'dart:async';
import 'dart:io';

import 'package:first_app/domain/target_ref.dart';
import 'package:first_app/domain/timer_state.dart';
import 'package:first_app/notifications/notification_service.dart';
import 'package:first_app/providers/timer_controller.dart';

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

  testWidgets('a cold start with a running timer opens the Timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
          restoredTimerProvider.overrideWithValue(
            TimerState.start(
              target: const TargetRef.custom('Reading'),
              workMin: 25,
              breakMin: 5,
              sessionId: 's_1',
              now: now.subtract(const Duration(minutes: 5)),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await settleIo(tester);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Timer'), findsOneWidget);
  });

  testWidgets('tapping the timer notification switches to the Timer', (
    tester,
  ) async {
    final taps = StreamController<String>.broadcast();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
          notificationsProvider.overrideWithValue(_TapNotifications(taps)),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await settleIo(tester);
    expect(find.text('Wed 14 Oct'), findsOneWidget);
    taps.add(timerPayload);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Timer'), findsOneWidget);
    await taps.close();
  });
}

class _TapNotifications extends NoNotifications {
  _TapNotifications(this._taps);

  final StreamController<String> _taps;

  @override
  Stream<String> get taps => _taps.stream;
}
