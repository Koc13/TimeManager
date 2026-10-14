/// A running (or paused) Pomodoro timer, as plain data.
///
/// Why wall-clock times instead of a counter that ticks each second: a
/// counter stops when Android kills the app. Storing *when* the current
/// stretch started (plus time accumulated before the last pause) lets the
/// remaining time be recomputed from the clock at any moment, including
/// after a restart.
library;

import 'target_ref.dart';

enum TimerPhase {
  /// A work block is counting down (or paused).
  work,

  /// The work block is done and saved; waiting for "start break" or "skip".
  breakOffer,

  /// The break is counting down (or paused). Breaks are never logged.
  onBreak,
}

class TimerState {
  const TimerState({
    required this.target,
    required this.workMin,
    required this.breakMin,
    required this.phase,
    required this.sessionId,
    required this.sessionStart,
    this.runningSince,
    this.elapsedBefore = Duration.zero,
  });

  /// A new work block, running from [now].
  TimerState.start({
    required this.target,
    required this.workMin,
    required this.breakMin,
    required this.sessionId,
    required DateTime now,
  }) : phase = TimerPhase.work,
       sessionStart = now,
       runningSince = now,
       elapsedBefore = Duration.zero;

  final TargetRef target;
  final int workMin;
  final int breakMin;
  final TimerPhase phase;

  /// Chosen when the work block starts, so writing the session is
  /// idempotent: finishing twice (say, after a crash) overwrites, never
  /// duplicates.
  final String sessionId;

  /// When the work block first started; becomes `Session.start`.
  final DateTime sessionStart;

  /// When the current running stretch began; null while paused or while
  /// waiting at the break offer.
  final DateTime? runningSince;

  /// Time counted before the current stretch (i.e. before the last pause).
  final Duration elapsedBefore;

  bool get isRunning => runningSince != null;

  Duration get length => Duration(
    minutes: switch (phase) {
      TimerPhase.work => workMin,
      TimerPhase.onBreak => breakMin,
      TimerPhase.breakOffer => 0,
    },
  );

  Duration elapsed(DateTime now) =>
      elapsedBefore +
      (runningSince == null ? Duration.zero : now.difference(runningSince!));

  Duration remaining(DateTime now) {
    final left = length - elapsed(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isOver(DateTime now) =>
      phase != TimerPhase.breakOffer && elapsed(now) >= length;

  /// When the current phase ends if it keeps running; null while paused.
  DateTime? get endsAt => runningSince?.add(length - elapsedBefore);

  TimerState pause(DateTime now) =>
      isRunning ? _copy(runningSince: null, elapsedBefore: elapsed(now)) : this;

  TimerState resume(DateTime now) =>
      isRunning ? this : _copy(runningSince: now, elapsedBefore: elapsedBefore);

  /// The work block is over: wait for the user to start or skip the break.
  TimerState offerBreak() => _copy(
    phase: TimerPhase.breakOffer,
    runningSince: null,
    elapsedBefore: Duration.zero,
  );

  TimerState startBreak(DateTime now) => _copy(
    phase: TimerPhase.onBreak,
    runningSince: now,
    elapsedBefore: Duration.zero,
  );

  TimerState _copy({
    TimerPhase? phase,
    required DateTime? runningSince,
    required Duration elapsedBefore,
  }) => TimerState(
    target: target,
    workMin: workMin,
    breakMin: breakMin,
    phase: phase ?? this.phase,
    sessionId: sessionId,
    sessionStart: sessionStart,
    runningSince: runningSince,
    elapsedBefore: elapsedBefore,
  );

  Map<String, Object?> toJson() => {
    'target': {'type': target.type.name, 'id': target.id, 'name': target.name},
    'work_min': workMin,
    'break_min': breakMin,
    'phase': phase.name,
    'session_id': sessionId,
    'session_start': sessionStart.toIso8601String(),
    'running_since': runningSince?.toIso8601String(),
    'elapsed_ms': elapsedBefore.inMilliseconds,
  };

  /// Null if [json] isn't a timer this version understands (the state is
  /// then simply dropped; it's device-local and short-lived).
  static TimerState? fromJson(Object? json) {
    try {
      final m = json as Map<String, Object?>;
      final t = m['target'] as Map<String, Object?>;
      final target = switch (t['type']) {
        'goal' => TargetRef.goal(t['id'] as String),
        'habit' => TargetRef.habit(t['id'] as String),
        _ => TargetRef.custom(t['name'] as String),
      };
      final since = m['running_since'] as String?;
      return TimerState(
        target: target,
        workMin: m['work_min'] as int,
        breakMin: m['break_min'] as int,
        phase: TimerPhase.values.byName(m['phase'] as String),
        sessionId: m['session_id'] as String,
        sessionStart: DateTime.parse(m['session_start'] as String),
        runningSince: since == null ? null : DateTime.parse(since),
        elapsedBefore: Duration(milliseconds: m['elapsed_ms'] as int),
      );
    } catch (_) {
      return null;
    }
  }
}
