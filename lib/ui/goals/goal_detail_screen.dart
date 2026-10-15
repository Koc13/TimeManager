import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/progress.dart';
import '../../providers/actions/activity_actions.dart';
import '../../providers/actions/goal_actions.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import 'goal_editor.dart';
import 'goal_feedback.dart';
import 'goals_screen.dart' show GoalRow, GoalsView;
import 'log_dialog.dart';
import '../theme/icons.dart';

enum _Action { edit, addSubGoal, complete, hold, reactivate, delete }

/// One goal: progress, sub-goals, log history; log progress, edit, status.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _log(BuildContext context, WidgetRef ref, Goal goal) async {
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
      if (reached.isEmpty) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              draft.amount == null
                  ? 'Logged'
                  : 'Logged ${amountLabel(draft.amount!, draft.unit)}',
            ),
          ),
        );
      }
      announceReached(messenger, ref, reached);
    });
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, Goal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(goal.title),
        content: const Text(
          'Mark this goal as complete? Its sub-goals and logs stay as they are.',
        ),
        actions: [
          NocButton.secondary(
            'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          NocButton('Complete', onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final goals = ref.read(goalActionsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await runAction(context, () => goals.setStatus(goal, GoalStatus.completed));
    messenger?.showSnackBar(
      SnackBar(
        content: const Text('Goal completed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => goals.setStatus(goal, GoalStatus.active),
        ),
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    _Action action,
  ) async {
    final goals = ref.read(goalActionsProvider);
    switch (action) {
      case _Action.edit:
        final draft = await showGoalEditor(context, goal: goal);
        if (draft == null || !context.mounted) return;
        await runAction(
          context,
          () => goals.saveGoal(
            goal.copyWith(
              title: draft.title,
              kind: draft.kind,
              target: draft.target,
              unit: draft.unit,
              parent: draft.parent,
            ),
          ),
        );
      case _Action.addSubGoal:
        final draft = await showGoalEditor(context, parent: goal.id);
        if (draft == null || !context.mounted) return;
        await runAction(
          context,
          () => goals.createGoal(
            title: draft.title,
            kind: draft.kind,
            target: draft.target,
            unit: draft.unit,
            parent: draft.parent,
          ),
        );
      case _Action.complete:
        await _complete(context, ref, goal);
      case _Action.hold:
        await runAction(
          context,
          () => goals.setStatus(goal, GoalStatus.onHold),
        );
      case _Action.reactivate:
        await runAction(
          context,
          () => goals.setStatus(goal, GoalStatus.active),
        );
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete “${goal.title}”?'),
            content: const Text(
              'Its file is deleted. Logs and sessions stay in your history; '
              'sub-goals become top-level goals.',
            ),
            actions: [
              NocButton.secondary(
                'Cancel',
                onPressed: () => Navigator.pop(context, false),
              ),
              NocButton(
                'Delete',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
        if (ok != true || !context.mounted) return;
        Navigator.pop(context);
        await goals.deleteGoal(goal.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final goal = data.goals[goalId];
    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This goal no longer exists')),
      );
    }
    final view = GoalsView(data);
    final children = view.children[goal.id] ?? const [];
    final logs = logsOf(data, goal.id);
    final p = view.progress[goal.id];
    // Measurable leaves get progress logged; parents and log goals are
    // completed by hand (log goals can still record entries).
    final measurableLeaf = goal.kind == GoalKind.measurable && children.isEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Ph.caretLeft, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Goal'),
        actions: [
          PopupMenuButton<_Action>(
            icon: const Icon(Ph.dotsThreeVertical, size: 22),
            onSelected: (a) => _act(context, ref, goal, a),
            itemBuilder: (_) => [
              const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
              const PopupMenuItem(
                value: _Action.addSubGoal,
                child: Text('Add sub-goal'),
              ),
              if (goal.status != GoalStatus.completed)
                const PopupMenuItem(
                  value: _Action.complete,
                  child: Text('Mark as complete'),
                ),
              if (goal.status != GoalStatus.onHold)
                const PopupMenuItem(
                  value: _Action.hold,
                  child: Text('Put on hold'),
                ),
              if (goal.status != GoalStatus.active)
                const PopupMenuItem(
                  value: _Action.reactivate,
                  child: Text('Reactivate'),
                ),
              const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
            ],
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: FadedRule(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Noc.gutter, 22, Noc.gutter, 40),
        children: [
          Kicker(switch (goal.status) {
            GoalStatus.active => 'Active',
            GoalStatus.onHold => 'On hold',
            GoalStatus.completed when goal.completed != null =>
              'Completed ${goal.completed!.day} ${monthName(goal.completed!.month)}',
            GoalStatus.completed => 'Completed',
          }),
          const SizedBox(height: 4),
          Text(goal.title, style: Noc.displaySmall),
          if (data.goals[goal.parent] case final parent?) ...[
            const SizedBox(height: 4),
            Text(
              'Part of ${parent.title}',
              style: Noc.meta.copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          if (p != null) ...[
            Row(
              children: [
                Expanded(child: NocProgress(value: p, thick: true)),
                const SizedBox(width: 12),
                Text(
                  '${(p * 100).round()}%',
                  style: Noc.title.copyWith(
                    color: Noc.accent300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          Text(view.amountText(goal), style: Noc.meta),
          if (goal.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            MarkdownBody(data: goal.notes),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              if (measurableLeaf || goal.kind == GoalKind.log)
                NocButton(
                  measurableLeaf ? 'Log progress' : 'Add log entry',
                  icon: Ph.plus,
                  onPressed: () => _log(context, ref, goal),
                ),
              if (!measurableLeaf && goal.status != GoalStatus.completed) ...[
                const SizedBox(width: 10),
                NocButton.secondary(
                  'Mark as complete',
                  onPressed: () => _complete(context, ref, goal),
                ),
              ],
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 34),
            const SectionTitle('Sub-goals'),
            const SizedBox(height: 6),
            for (final child in children)
              GoalRow(
                row: (
                  goal: child,
                  depth: 0,
                  progress: view.progress[child.id],
                  amount: view.amountText(child),
                ),
              ),
          ],
          const SizedBox(height: 34),
          SectionTitle('Log history', count: '${logs.length}'),
          const SizedBox(height: 6),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nothing logged yet.',
                style: TextStyle(fontSize: 13, color: Noc.neutral500),
              ),
            ),
          for (final (:day, :log) in logs)
            Ruled(
              child: InkWell(
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete this log entry?'),
                      actions: [
                        NocButton.secondary(
                          'Cancel',
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        NocButton(
                          'Delete',
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await runAction(
                      context,
                      () => ref
                          .read(activityActionsProvider)
                          .deleteGoalLog(day, log.id),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          dayLabel(log.at).substring(4),
                          style: Noc.meta,
                        ),
                      ),
                      Expanded(
                        child: Text(log.source ?? '', style: Noc.secondary),
                      ),
                      if (log.amount != null)
                        Text(
                          amountLabel(log.amount!, log.unit),
                          style: Noc.secondary.copyWith(
                            color: Noc.neutral300,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
