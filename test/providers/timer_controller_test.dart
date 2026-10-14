import 'dart:io';

import 'package:first_app/domain/goal.dart';
import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/target_ref.dart';
import 'package:first_app/domain/timer_state.dart';
import 'package:first_app/notifications/notification_service.dart';
import 'package:first_app/providers/data_providers.dart';
import 'package:first_app/providers/timer_controller.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:first_app/storage/local_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which notification calls were made.
class FakeNotifications extends NoNotifications {
  final calls = <String>[];

  @override
  Future<void> showTimerRunning({
    required String title,
    required DateTime end,
  }) async => calls.add('running');
  @override
  Future<void> showTimerPaused({
    required String title,
    required String text,
  }) async => calls.add('paused');
  @override
  Future<void> scheduleTimerEnd({
    required String title,
    required String body,
    required DateTime at,
  }) async => calls.add('alarm');
  @override
  Future<void> cancelTimer() async => calls.add('cancel');
  @override
  Future<void> hideTimerRunning() async => calls.add('hide');
}

void main() {
  late Directory dir;
  late DataStore store;
  late LocalSettings settings;
  late FakeNotifications notifications;
  late DateTime now;
  final t0 = DateTime(2026, 10, 14, 9);
  final today = Day(DateTime(2026, 10, 14));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_timer');
    store = await DataStore.open('${dir.path}/data');
    settings = LocalSettings(File('${dir.path}/local.json'));
    notifications = FakeNotifications();
    now = t0;
  });
  tearDown(() => dir.delete(recursive: true));

  ProviderContainer container({TimerState? restored}) {
    final c = ProviderContainer(
      overrides: [
        dataStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
        localSettingsProvider.overrideWithValue(settings),
        notificationsProvider.overrideWithValue(notifications),
        restoredTimerProvider.overrideWithValue(restored),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a finished work block is saved and a break is offered', () async {
    final c = container();
    final timer = c.read(timerProvider.notifier);
    await timer.start(
      const TargetRef.custom('Tax forms'),
      workMin: 25,
      breakMin: 5,
    );
    expect(notifications.calls, ['running', 'alarm']);

    now = t0.add(const Duration(minutes: 25));
    await timer.tick();

    final session = store.data.period(today).sessions.single;
    expect(
      (session.plannedMin, session.actualMin, session.start),
      (25, 25, t0),
    );
    expect(c.read(timerProvider)!.phase, TimerPhase.breakOffer);
    // The OS alarm is left to ring; only the countdown goes.
    expect(notifications.calls.last, 'hide');
    expect(await settings.timer(), isNotNull, reason: 'persisted');
  });

  test('a break is not logged and ends the timer', () async {
    final c = container();
    final timer = c.read(timerProvider.notifier);
    await timer.start(const TargetRef.custom('X'), workMin: 25, breakMin: 5);
    now = t0.add(const Duration(minutes: 25));
    await timer.tick();
    await timer.startBreak();
    now = t0.add(const Duration(minutes: 30));
    await timer.tick();
    expect(c.read(timerProvider), isNull);
    expect(store.data.period(today).sessions, hasLength(1));
    expect(await settings.timer(), isNull);
  });

  test('stopping early keeps whole minutes, or nothing under one', () async {
    final c = container();
    final timer = c.read(timerProvider.notifier);
    await timer.start(const TargetRef.custom('X'), workMin: 25, breakMin: 5);
    now = t0.add(const Duration(minutes: 12, seconds: 40));
    await timer.stop(keep: true);
    expect(store.data.period(today).sessions.single.actualMin, 12);
    expect(notifications.calls.last, 'cancel');

    await timer.start(const TargetRef.custom('Y'), workMin: 25, breakMin: 5);
    now = now.add(const Duration(seconds: 50));
    await timer.stop(keep: true);
    expect(store.data.period(today).sessions, hasLength(1));
  });

  test(
    'a block that ended while the app was dead is saved once on start',
    () async {
      // The app was killed mid-block; it comes back long after the end.
      final restored = TimerState.start(
        target: const TargetRef.custom('X'),
        workMin: 25,
        breakMin: 5,
        sessionId: 's_fixed',
        now: t0,
      );
      now = t0.add(const Duration(hours: 2));
      final c = container(restored: restored);
      c.read(timerProvider);
      await c.read(timerProvider.notifier).tick(); // races the start-up check
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final sessions = store.data.period(today).sessions;
      expect(sessions.single.id, 's_fixed');
      expect(sessions.single.actualMin, 25, reason: 'no overflow');
      expect(c.read(timerProvider)!.phase, TimerPhase.breakOffer);
    },
  );

  test('a paused timer survives a restart with the same time left', () async {
    final c = container();
    final timer = c.read(timerProvider.notifier);
    await timer.start(const TargetRef.custom('X'), workMin: 25, breakMin: 5);
    now = t0.add(const Duration(minutes: 5));
    await timer.pause();
    expect(notifications.calls.last, 'paused');

    now = t0.add(const Duration(hours: 3));
    final restored = TimerState.fromJson(await settings.timer());
    final c2 = container(restored: restored);
    expect(c2.read(timerProvider)!.remaining(now), const Duration(minutes: 20));
  });

  test('a session on a minutes goal completes it and is announced', () async {
    await store.saveGoal(
      Goal(id: 'g_1', title: 'Study', target: 25, unit: 'min', created: t0),
    );
    final c = container();
    final timer = c.read(timerProvider.notifier);
    await timer.start(const TargetRef.goal('g_1'), workMin: 25, breakMin: 5);
    now = t0.add(const Duration(minutes: 25));
    await timer.tick();
    expect(store.data.goals['g_1']!.status, GoalStatus.completed);
    expect(c.read(reachedGoalsProvider).single.id, 'g_1');
  });
}
