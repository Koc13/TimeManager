import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/progress.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../todo/done_section.dart' show SectionHeader;
import 'goal_editor.dart';
import 'goal_feedback.dart';
import 'goals_screen.dart' show GoalRow, goalProgressLabel;
import 'log_dialog.dart';
import '../../providers/actions/activity_actions.dart';
import '../../providers/actions/goal_actions.dart';

enum _Action { edit, addSubGoal, complete, hold, reactivate, delete }

/// One goal: progress, sub-goals, log history, add a log, edit, status.
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
      announceReached(messenger, ref, reached);
    });
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
    _Action action,
  ) async {
    final data = ref.read(goalActionsProvider);
    switch (action) {
      case _Action.edit:
        final draft = await showGoalEditor(context, goal: goal);
        if (draft == null || !context.mounted) return;
        await runAction(
          context,
          () => data.saveGoal(
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
          () => data.createGoal(
            title: draft.title,
            kind: draft.kind,
            target: draft.target,
            unit: draft.unit,
            parent: draft.parent,
          ),
        );
      case _Action.complete:
        await runAction(
          context,
          () => data.setStatus(goal, GoalStatus.completed),
        );
      case _Action.hold:
        await runAction(context, () => data.setStatus(goal, GoalStatus.onHold));
      case _Action.reactivate:
        await runAction(context, () => data.setStatus(goal, GoalStatus.active));
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete "${goal.title}"?'),
            content: const Text(
              'Its file is deleted. Logs and sessions stay in your history; '
              'sub-goals become top-level goals.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true || !context.mounted) return;
        Navigator.pop(context);
        await data.deleteGoal(goal.id);
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
    final amounts = goalAmounts(data);
    final progress = goalProgress(data, amounts);
    final children = childrenByParent(data.goals.values)[goal.id] ?? const [];
    final logs = logsOf(data, goal.id);
    final p = progress[goal.id];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          PopupMenuButton<_Action>(
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
                  child: Text('Mark completed'),
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
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p != null) ...[
                  LinearProgressIndicator(
                    value: p.clamp(0.0, 1.0),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  goalProgressLabel(
                    goal,
                    p,
                    amounts[goal.id] ?? 0,
                    children.length,
                    logs.length,
                  ),
                  style: theme.textTheme.titleMedium,
                ),
                Text(switch (goal.status) {
                  GoalStatus.active => 'Active',
                  GoalStatus.onHold => 'On hold',
                  GoalStatus.completed => 'Completed',
                }, style: theme.textTheme.bodySmall),
                if (goal.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  MarkdownBody(data: goal.notes),
                ],
              ],
            ),
          ),
          if (children.isNotEmpty) ...[
            const SectionHeader('Sub-goals'),
            for (final child in children)
              GoalRow(
                goal: child,
                depth: 0,
                progress: progress[child.id],
                amount: amounts[child.id] ?? 0,
                childCount:
                    childrenByParent(data.goals.values)[child.id]?.length ?? 0,
                logCount: logsOf(data, child.id).length,
              ),
          ],
          const SectionHeader('Log history'),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Nothing logged yet',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
          for (final (:day, :log) in logs)
            ListTile(
              dense: true,
              title: Text(
                [
                  if (log.amount != null) amountLabel(log.amount!, log.unit),
                  if (log.source != null) log.source!,
                ].join(' · '),
              ),
              subtitle: Text(dateTimeLabel(log.at)),
              onLongPress: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete this log entry?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
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
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _log(context, ref, goal),
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
    );
  }
}
