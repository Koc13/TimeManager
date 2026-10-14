import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/goal.dart';
import '../../domain/period.dart';
import '../../domain/target_ref.dart';
import '../../domain/timer_state.dart';
import '../../providers/data_providers.dart';
import '../../providers/timer_controller.dart';
import '../feedback.dart';
import '../format.dart';
import '../goals/goal_feedback.dart';
import '../goals/log_dialog.dart';
import '../todo/done_section.dart' show SectionHeader;

/// Pick a topic and presets, then a big countdown; today's totals below.
class TimerScreen extends ConsumerWidget {
  const TimerScreen({
    super.key,
    required this.scaffoldKey,
    required this.drawer,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      appBar: AppBar(title: const Text('Timer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          switch (timer?.phase) {
            null => const _Setup(),
            TimerPhase.breakOffer => _BreakOffer(timer: timer!),
            _ => _Countdown(timer: timer!),
          },
          const _TodayTotals(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ setup

class _Setup extends ConsumerStatefulWidget {
  const _Setup();

  @override
  ConsumerState<_Setup> createState() => _SetupState();
}

class _SetupState extends ConsumerState<_Setup> {
  final _query = TextEditingController();
  TargetRef? _target;
  int _work = 25;
  int _break = 5;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final query = _query.text.trim();
    final target = _target;

    if (target == null) {
      final q = query.toLowerCase();
      final matches = [
        for (final g in data.goals.values)
          if (g.status == GoalStatus.active &&
              g.title.toLowerCase().contains(q))
            (TargetRef.goal(g.id), g.title, Icons.flag_outlined),
        for (final h in data.habits.values)
          if (h.title.toLowerCase().contains(q))
            (TargetRef.habit(h.id), h.title, Icons.repeat),
      ]..sort((a, b) => a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Goal, habit, or a new name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (text) {
              if (text.trim().isNotEmpty) {
                setState(() => _target = TargetRef.custom(text.trim()));
              }
            },
          ),
          if (query.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('Custom session: "$query"'),
              onTap: () => setState(() => _target = TargetRef.custom(query)),
            ),
          for (final (option, title, icon) in matches.take(8))
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              onTap: () => setState(() => _target = option),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.track_changes),
          title: Text(targetName(data, target)),
          trailing: TextButton(
            onPressed: () => setState(() => _target = null),
            child: const Text('Change'),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Work'),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 25, label: Text('25 min')),
            ButtonSegment(value: 50, label: Text('50 min')),
          ],
          selected: {_work},
          onSelectionChanged: (s) => setState(() => _work = s.single),
        ),
        const SizedBox(height: 16),
        const Text('Break'),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5')),
            ButtonSegment(value: 10, label: Text('10')),
            ButtonSegment(value: 20, label: Text('20')),
          ],
          selected: {_break},
          onSelectionChanged: (s) => setState(() => _break = s.single),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => runAction(
            context,
            () => ref
                .read(timerProvider.notifier)
                .start(target, workMin: _work, breakMin: _break),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- countdown

class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.timer});

  final TimerState timer;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  // Only repaints the display. The time itself always comes from the clock.
  late final Timer _repaint = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _repaint; // start it
  }

  @override
  void dispose() {
    _repaint.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    final controller = ref.read(timerProvider.notifier);
    final timer = widget.timer;
    if (timer.phase != TimerPhase.work) {
      await controller.stop(keep: false);
      return;
    }
    final minutes = timer.elapsed(ref.read(clockProvider)()).inMinutes;
    if (minutes < 1) {
      // Spec: only sessions of a minute or more are kept, so don't ask.
      await controller.stop(keep: false);
      return;
    }
    await controller.pause();
    if (!mounted) return;
    final keep = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Keep this $minutes min session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await runAction(
      context,
      () => keep == null ? controller.resume() : controller.stop(keep: keep),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final now = ref.watch(clockProvider)();
    final left = timer.remaining(now);
    final total = timer.length.inSeconds;
    final theme = Theme.of(context);
    final controller = ref.read(timerProvider.notifier);
    final onBreak = timer.phase == TimerPhase.onBreak;

    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          onBreak
              ? 'Break'
              : targetName(ref.watch(appDataProvider), timer.target),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox.square(
          dimension: 240,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: total == 0 ? 0 : left.inSeconds / total,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                color: onBreak ? theme.colorScheme.tertiary : null,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              Center(
                child: Text(
                  countdownLabel(left),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => runAction(
                context,
                timer.isRunning ? controller.pause : controller.resume,
              ),
              icon: Icon(timer.isRunning ? Icons.pause : Icons.play_arrow),
              label: Text(timer.isRunning ? 'Pause' : 'Resume'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
      ],
    );
  }
}

/// "24:59". Minutes are not wrapped into hours: blocks are at most 50 min.
String countdownLabel(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

// ------------------------------------------------------------ break offer

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          'Saved ${timer.workMin} min on ${targetName(data, timer.target)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => runAction(context, controller.startBreak),
          icon: const Icon(Icons.free_breakfast_outlined),
          label: Text('Start ${timer.breakMin} min break'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => runAction(context, controller.skipBreak),
          child: const Text('Skip break'),
        ),
        // After a session on a log goal, offer an optional log.
        if (goal != null && goal.kind == GoalKind.log) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final draft = await showLogDialog(context, goal);
              if (draft == null || !context.mounted) return;
              final messenger = ScaffoldMessenger.maybeOf(context);
              await runAction(context, () async {
                final reached = await ref
                    .read(appDataProvider.notifier)
                    .addGoalLog(
                      goal: goal.id,
                      amount: draft.amount,
                      unit: draft.unit,
                      source: draft.source,
                    );
                announceReached(messenger, ref, reached);
              });
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Add a log entry (optional)'),
          ),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------- today totals

class _TodayTotals extends ConsumerWidget {
  const _TodayTotals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final today = Day(ref.watch(todayProvider));
    final sessions = activityIn(data, today).sessions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const SectionHeader('Today'),
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No sessions yet',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        for (final s in sessions)
          ListTile(
            dense: true,
            title: Text(targetName(data, s.target)),
            trailing: Text(
              '${minutesLabel(s.minutes)} · ${s.count} session${s.count == 1 ? '' : 's'}',
            ),
          ),
      ],
    );
  }
}
