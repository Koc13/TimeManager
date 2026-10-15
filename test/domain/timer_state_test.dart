import 'package:time_manager/domain/target_ref.dart';
import 'package:time_manager/domain/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 9);
  DateTime at(int minutes, [int seconds = 0]) =>
      t0.add(Duration(minutes: minutes, seconds: seconds));

  TimerState start() => TimerState.start(
    target: const TargetRef.goal('g_1'),
    workMin: 25,
    breakMin: 5,
    sessionId: 's_1',
    now: t0,
  );

  test('remaining time comes from the clock', () {
    final s = start();
    expect(s.remaining(at(10)), const Duration(minutes: 15));
    expect(s.endsAt, at(25));
    expect(s.isOver(at(24, 59)), isFalse);
    expect(s.isOver(at(25)), isTrue);
    expect(s.remaining(at(40)), Duration.zero);
  });

  test('pausing freezes elapsed time; resuming continues from there', () {
    final paused = start().pause(at(10));
    expect(paused.isRunning, isFalse);
    expect(paused.endsAt, isNull);
    expect(paused.remaining(at(60)), const Duration(minutes: 15));

    final resumed = paused.resume(at(60));
    expect(resumed.remaining(at(65)), const Duration(minutes: 10));
    expect(resumed.endsAt, at(75));
    expect(
      resumed.sessionStart,
      t0,
      reason: 'session start is the first start',
    );
  });

  test('break offer, then a break of breakMin', () {
    final offer = start().offerBreak();
    expect(offer.phase, TimerPhase.breakOffer);
    expect(offer.isOver(at(100)), isFalse);
    final brk = offer.startBreak(at(30));
    expect(brk.remaining(at(32)), const Duration(minutes: 3));
    expect(brk.isOver(at(35)), isTrue);
  });

  test('JSON round-trip keeps everything, including a paused state', () {
    for (final s in [
      start(),
      start().pause(at(7, 30)),
      TimerState.start(
        target: const TargetRef.custom('Tax forms'),
        workMin: 50,
        breakMin: 10,
        sessionId: 's_2',
        now: t0,
      ).offerBreak(),
    ]) {
      final back = TimerState.fromJson(s.toJson())!;
      expect(back.toJson(), s.toJson());
      expect(back.remaining(at(12)), s.remaining(at(12)));
    }
  });

  test('unreadable JSON is dropped, not a crash', () {
    expect(TimerState.fromJson({'phase': 'warp'}), isNull);
    expect(TimerState.fromJson(null), isNull);
  });
}
