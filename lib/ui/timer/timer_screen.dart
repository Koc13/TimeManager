import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/goal.dart';
import '../../domain/period.dart';
import '../../domain/target_ref.dart';
import '../../domain/timer_state.dart';
import '../../providers/actions/activity_actions.dart';
import '../../providers/data_providers.dart';
import '../../providers/timer_controller.dart';
import '../feedback.dart';
import '../format.dart';
import '../goals/goal_feedback.dart';
import '../goals/log_dialog.dart';
import '../noc_app_bar.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import '../theme/icons.dart';

/// Work/break presets (minutes), as in the design.
const presets = [(25, 5), (50, 10), (90, 15)];

/// Pick what you're working on and a preset, then a ring counting down;
/// today's sessions below.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({
    super.key,
    required this.scaffoldKey,
    required this.drawer,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  TargetRef? _target;
  int _preset = 0;
  Timer? _repaint;

  @override
  void dispose() {
    _repaint?.cancel();
    super.dispose();
  }

  /// Repaints once a second while something counts down. The time itself
  /// always comes from the clock (see TimerState).
  void _syncRepaint(TimerState? timer) {
    final running = timer?.isRunning ?? false;
    if (running && _repaint == null) {
      _repaint = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _repaint?.cancel();
      _repaint = null;
    }
  }

  Future<void> _pickTarget() async {
    final picked = await showModalBottomSheet<TargetRef>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TargetSheet(),
    );
    if (picked != null) setState(() => _target = picked);
  }

  Future<void> _start() async {
    final (work, rest) = presets[_preset];
    await runAction(
      context,
      () => ref
          .read(timerProvider.notifier)
          .start(
            _target ?? const TargetRef.custom('Focus'),
            workMin: work,
            breakMin: rest,
          ),
    );
  }

  Future<void> _stop(TimerState timer) async {
    final controller = ref.read(timerProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (timer.phase != TimerPhase.work) {
      await controller.stop(keep: false);
      return;
    }
    final minutes = timer.elapsed(ref.read(clockProvider)()).inMinutes;
    if (minutes < 1) {
      // Spec: only sessions of a minute or more are kept, so don't ask.
      await controller.stop(keep: false);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Under a minute — not saved')),
      );
      return;
    }
    await controller.pause();
    if (!mounted) return;
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop this block?'),
        content: Text(
          'You’ve worked $minutes min. Keep it as a session, discard it, or carry on.',
        ),
        actionsOverflowButtonSpacing: 8,
        actions: [
          NocButton.ghost(
            'Discard',
            onPressed: () => Navigator.pop(context, false),
          ),
          NocButton.secondary(
            'Continue',
            onPressed: () => Navigator.pop(context),
          ),
          NocButton(
            'Keep $minutes min',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await runAction(
      context,
      () => keep == null ? controller.resume() : controller.stop(keep: keep),
    );
    if (keep == true) {
      messenger?.showSnackBar(SnackBar(content: Text('Saved $minutes min')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final data = ref.watch(appDataProvider);
    final now = ref.read(clockProvider)();
    _syncRepaint(timer);
    final controller = ref.read(timerProvider.notifier);

    final (work, rest) = presets[_preset];
    final target = timer?.target ?? _target;
    final phase = timer?.phase;
    final remaining = switch (timer) {
      null => Duration(minutes: work),
      final t => t.remaining(now),
    };
    final total = timer == null ? Duration(minutes: work) : timer.length;
    final fraction = total.inSeconds == 0
        ? 0.0
        : remaining.inSeconds / total.inSeconds;
    final running = timer?.isRunning ?? false;

    final phaseLabel = switch (phase) {
      null => 'Ready',
      TimerPhase.work => running ? 'Working' : 'Paused',
      TimerPhase.onBreak => running ? 'Break' : 'Break paused',
      TimerPhase.breakOffer => 'Block complete',
    };
    final phaseSub = switch (phase) {
      null => '$work min work · $rest min break',
      TimerPhase.work => 'of ${timer!.workMin} min',
      TimerPhase.onBreak => 'of ${timer!.breakMin} min break',
      TimerPhase.breakOffer => 'Time for a rest',
    };

    return Scaffold(
      key: widget.scaffoldKey,
      drawer: widget.drawer,
      appBar: NocAppBar(scaffoldKey: widget.scaffoldKey, title: 'Timer'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Noc.gutter, 22, Noc.gutter, 40),
        children: [
          _WorkingOn(
            name: target == null
                ? 'Choose a goal or habit'
                : targetName(data, target),
            locked: timer != null,
            onTap: _pickTarget,
          ),
          const SizedBox(height: 30),
          Center(
            child: SizedBox.square(
              dimension: 280,
              child: CustomPaint(
                painter: _RingPainter(fraction),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        phaseLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: Noc.neutral400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(countdown(remaining), style: Noc.clock),
                      const SizedBox(height: 8),
                      Text(phaseSub, style: Noc.meta),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (timer == null) ...[
            Center(
              child: NocSegmented<int>(
                minWidth: 80,
                options: [
                  for (final (i, (w, b)) in presets.indexed) (i, '$w + $b'),
                ],
                selected: _preset,
                onChanged: (i) => setState(() => _preset = i),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: NocButton(
                'Start block',
                big: true,
                icon: Ph.play,
                onPressed: _start,
              ),
            ),
          ] else if (phase == TimerPhase.breakOffer)
            _BreakOffer(timer: timer)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: NocButton(
                    running ? 'Pause' : 'Resume',
                    big: true,
                    onPressed: () => runAction(
                      context,
                      running ? controller.pause : controller.resume,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: NocButton.secondary(
                    phase == TimerPhase.onBreak ? 'Skip break' : 'Stop',
                    big: true,
                    onPressed: () => _stop(timer),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 40),
          const _TodaySessions(),
        ],
      ),
    );
  }
}

/// The "Working on" picker; locked while a block runs.
class _WorkingOn extends StatelessWidget {
  const _WorkingOn({
    required this.name,
    required this.locked,
    required this.onTap,
  });

  final String name;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: locked ? null : onTap,
    borderRadius: BorderRadius.circular(Noc.rMd),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Noc.divider),
        borderRadius: BorderRadius.circular(Noc.rMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('Working on'),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!locked) const Icon(Ph.caretRight, size: 18),
        ],
      ),
    ),
  );
}

/// The countdown ring: 1px track, 2px accent arc from 12 o'clock that
/// empties clockwise as time runs out. No glow.
class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 128.0;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Noc.divider,
    );
    final sweep = 2 * pi * fraction.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Noc.accent,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}

/// "Block saved" card at the end of a work block.
class _BreakOffer extends ConsumerWidget {
  const _BreakOffer({required this.timer});

  final TimerState timer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final controller = ref.read(timerProvider.notifier);
    final goal = timer.target.type == TargetType.goal
        ? data.goals[timer.target.id]
        : null;

    return NocCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Kicker('Block saved'),
          const SizedBox(height: 6),
          Text(
            '${timer.workMin} min on ${targetName(data, timer.target)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NocButton(
                'Start ${timer.breakMin} min break',
                onPressed: () => runAction(context, controller.startBreak),
              ),
              const SizedBox(width: 10),
              NocButton.secondary(
                'Skip',
                onPressed: () => runAction(context, controller.skipBreak),
              ),
            ],
          ),
          // After a session on a log goal, offer an optional log.
          if (goal != null && goal.kind == GoalKind.log) ...[
            const SizedBox(height: 6),
            NocButton.ghost(
              'Add a log entry (optional)',
              small: true,
              onPressed: () async {
                final draft = await showLogDialog(context, goal);
                if (draft == null || !context.mounted) return;
                final messenger = ScaffoldMessenger.maybeOf(context);
                await runAction(context, () async {
                  final reached = await ref
                      .read(activityActionsProvider)
                      .addGoalLog(
                        goal: goal.id,
                        amount: draft.amount,
                        unit: draft.unit,
                        source: draft.source,
                      );
                  announceReached(messenger, ref, reached);
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Today's sessions, newest first: start time · target · duration.
class _TodaySessions extends ConsumerWidget {
  const _TodaySessions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final today = Day(ref.watch(todayProvider));
    final sessions = [...data.period(today).sessions]
      ..sort((a, b) => b.start.compareTo(a.start));
    final total = sessions.fold<int>(0, (a, s) => a + s.actualMin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ruled(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Expanded(
                  child: Text(
                    'Today',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  sessions.isEmpty ? '' : minutesLabel(total),
                  style: Noc.meta,
                ),
              ],
            ),
          ),
        ),
        if (sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No sessions yet.',
              style: TextStyle(fontSize: 13, color: Noc.neutral500),
            ),
          ),
        for (final s in sessions)
          Ruled(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      timeLabel(s.start),
                      style: Noc.meta.copyWith(color: Noc.neutral500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      targetName(data, s.target),
                      style: Noc.secondary,
                    ),
                  ),
                  Text(
                    minutesLabel(s.actualMin),
                    style: Noc.secondary.copyWith(
                      color: Noc.neutral300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Search goals and habits, or start a custom session by name.
class _TargetSheet extends ConsumerStatefulWidget {
  const _TargetSheet();

  @override
  ConsumerState<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<_TargetSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final query = _query.text.trim();
    final q = query.toLowerCase();
    final rows = [
      for (final g in data.goals.values)
        if (g.status == GoalStatus.active && g.title.toLowerCase().contains(q))
          (TargetRef.goal(g.id), g.title, 'Goal'),
      for (final h in data.habits.values)
        if (h.title.toLowerCase().contains(q))
          (TargetRef.habit(h.id), h.title, 'Habit'),
    ]..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
    final exact = rows.any((r) => r.$2.toLowerCase() == q);

    Widget row(
      String label,
      VoidCallback onTap, {
      String? kind,
      Color? color,
    }) => Ruled(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: color ?? Noc.text),
                ),
              ),
              if (kind != null)
                Text(
                  kind.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.9,
                    color: Noc.neutral500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
            children: [
              const Text(
                'What are you working on?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search goals and habits, or type a name',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    Navigator.pop(context, TargetRef.custom(text.trim()));
                  }
                },
              ),
              const SizedBox(height: 8),
              if (query.isNotEmpty && !exact)
                row(
                  'Start “$query”',
                  () => Navigator.pop(context, TargetRef.custom(query)),
                  color: Noc.accent300,
                ),
              for (final (target, title, kind) in rows)
                row(title, () => Navigator.pop(context, target), kind: kind),
            ],
          ),
        ),
      ),
    );
  }
}
