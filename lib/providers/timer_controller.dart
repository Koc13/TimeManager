import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity.dart';
import '../domain/aggregation.dart';
import '../domain/ids.dart';
import '../domain/target_ref.dart';
import '../domain/timer_state.dart';
import 'data_providers.dart';

/// The timer that was running when the app last stopped, read from local
/// settings before the app starts (app.dart overrides this).
final restoredTimerProvider = Provider<TimerState?>((ref) => null);

final timerProvider = NotifierProvider<TimerController, TimerState?>(
  TimerController.new,
);

/// Owns the one timer. Every change goes through [_set], which persists the
/// state (so it survives the app being killed), re-arms the in-app alarm and
/// updates the notifications.
///
/// Two alarms on purpose: a Dart [Timer] finishes the block while the app
/// runs; the OS alarm (scheduled notification) rings even when it doesn't.
/// If the app was dead at the end, [tick] on the next start catches up.
class TimerController extends Notifier<TimerState?> {
  Timer? _alarm;

  /// Guards [tick]: on restore, the start-up check and a zero-length alarm
  /// can both fire while the first one is still writing the session.
  bool _ticking = false;

  DateTime _now() => ref.read(clockProvider)();

  @override
  TimerState? build() {
    ref.onDispose(() => _alarm?.cancel());
    final restored = ref.read(restoredTimerProvider);
    _arm(restored);
    // A block that ended while the app was dead gets finished now.
    Future.microtask(tick);
    return restored;
  }

  Future<void> start(
    TargetRef target, {
    required int workMin,
    required int breakMin,
  }) async {
    await ref.read(notificationsProvider).requestPermission();
    await _set(
      TimerState.start(
        target: target,
        workMin: workMin,
        breakMin: breakMin,
        sessionId: newId('s'),
        now: _now(),
      ),
    );
  }

  Future<void> pause() async {
    if (state case final s?) await _set(s.pause(_now()));
  }

  Future<void> resume() async {
    if (state case final s?) await _set(s.resume(_now()));
  }

  Future<void> startBreak() async {
    if (state case final s?) await _set(s.startBreak(_now()));
  }

  Future<void> skipBreak() => _set(null);

  /// Stops early. A work block is saved with its whole minutes so far when
  /// [keep] is true and at least one minute ran; a break is just
  /// dropped.
  Future<void> stop({required bool keep}) async {
    final s = state;
    if (s == null) return;
    final minutes = s.elapsed(_now()).inMinutes;
    if (s.phase == TimerPhase.work && keep && minutes >= 1) {
      await _record(s, minutes);
    }
    await _set(null);
  }

  /// Finishes the current phase if its time is up. Called by the in-app
  /// alarm, on start, and on resume.
  Future<void> tick() async {
    final s = state;
    if (_ticking || s == null || !s.isOver(_now())) return;
    _ticking = true;
    try {
      if (s.phase == TimerPhase.work) {
        // No overflow: a block that ran past its end (app asleep) counts
        // as exactly its planned length.
        await _record(s, s.workMin);
        await _set(s.offerBreak(), finished: true);
      } else {
        await _set(null, finished: true);
      }
    } finally {
      _ticking = false;
    }
  }

  Future<void> _record(TimerState s, int minutes) async {
    final reached = await ref
        .read(appDataProvider.notifier)
        .recordSession(
          Session(
            id: s.sessionId,
            target: s.target,
            start: s.sessionStart,
            plannedMin: s.workMin,
            actualMin: minutes,
          ),
        );
    ref.read(reachedGoalsProvider.notifier).announce(reached);
  }

  Future<void> _set(TimerState? next, {bool finished = false}) async {
    state = next;
    _arm(next);
    await ref.read(localSettingsProvider)?.setTimer(next?.toJson());

    final notify = ref.read(notificationsProvider);
    if (next == null || next.phase == TimerPhase.breakOffer) {
      // A natural end leaves the OS alarm alone so it can still ring.
      await (finished ? notify.hideTimerRunning() : notify.cancelTimer());
      return;
    }
    final title = _title(next);
    final end = next.endsAt;
    if (end == null) {
      final left = next.remaining(_now());
      await notify.showTimerPaused(
        title: title,
        text:
            'Paused · ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')} left',
      );
    } else {
      await notify.showTimerRunning(title: title, end: end);
      await notify.scheduleTimerEnd(
        title: next.phase == TimerPhase.work ? 'Work block done' : 'Break over',
        body: next.phase == TimerPhase.work
            ? '${next.workMin} min on ${_targetName(next)}. Time for a break.'
            : 'Back to it.',
        at: end,
      );
    }
  }

  void _arm(TimerState? s) {
    _alarm?.cancel();
    final end = s?.endsAt;
    if (end == null) return;
    final wait = end.difference(_now());
    _alarm = Timer(wait.isNegative ? Duration.zero : wait, tick);
  }

  String _targetName(TimerState s) =>
      targetName(ref.read(appDataProvider), s.target);

  String _title(TimerState s) =>
      '${_targetName(s)} · ${s.phase == TimerPhase.work ? 'Work' : 'Break'}';
}
