import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/target_ref.dart';
import 'package:time_manager/domain/timer_state.dart';
import 'package:time_manager/notifications/notification_service.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/providers/timer_controller.dart';
import 'package:time_manager/storage/data_store.dart';

import 'helpers.dart';

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

  testWidgets('pick a custom topic, run, stop early and keep it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      store,
      now,
      clock: () => now,
    );
    await openSection(tester, 'Timer');
    expect(find.text('No sessions yet.'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);

    await tester.tap(find.text('Choose a goal or habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tax forms');
    await tester.pump();
    await tester.tap(find.text('Start “Tax forms”'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 + 10'));
    await tester.pump();
    expect(find.text('50:00'), findsOneWidget);
    await tester.tap(find.text('Start block'));
    await settleIo(tester, settle: false);
    expect(find.text('WORKING'), findsOneWidget);

    now = now.add(const Duration(minutes: 7, seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('42:55'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stop this block?'), findsOneWidget);
    await tester.tap(find.text('Keep 7 min'));
    await settleIo(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('7 min'), findsWidgets); // today's list and total
    expect(
      File('${dir.path}/periods/2026/10/2026-10-14.md').readAsStringSync(),
      contains('target: {type: custom, name: Tax forms}'),
    );
  });

  testWidgets('a cold start with a running timer opens the Timer', (
    tester,
  ) async {
    await pumpApp(
      tester,
      store,
      now,
      overrides: [
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
    );
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('WORKING'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget); // locked "Working on"
  });

  testWidgets('notification taps switch section and list', (tester) async {
    final taps = StreamController<String>.broadcast();
    await pumpApp(
      tester,
      store,
      now,
      overrides: [
        notificationsProvider.overrideWithValue(_TapNotifications(taps)),
      ],
    );
    expect(find.text('Wednesday'), findsOneWidget);
    taps.add(timerPayload);
    await tester.pumpAndSettle();
    expect(find.text('READY'), findsOneWidget);

    // A weekly review reminder opens the weekly list.
    taps.add('open:week');
    await tester.pumpAndSettle();
    expect(find.text('Week 42'), findsOneWidget);
    await taps.close();
  });
}

class _TapNotifications extends NoNotifications {
  _TapNotifications(this._taps);

  final StreamController<String> _taps;

  @override
  Stream<String> get taps => _taps.stream;
}
