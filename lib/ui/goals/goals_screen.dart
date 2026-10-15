import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_data.dart';
import '../../domain/goal.dart';
import '../../domain/progress.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../todo/done_section.dart' show SectionHeader;
import 'goal_detail_screen.dart';
import 'goal_editor.dart';
import '../../providers/actions/goal_actions.dart';

/// Active goals with progress bars (sub-goals indented), then On hold
/// (collapsed), then Completed with dates: one scroll.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({
    super.key,
    required this.scaffoldKey,
    required this.drawer,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showGoalEditor(context);
    if (draft == null || !context.mounted) return;
    await runAction(
      context,
      () => ref
          .read(goalActionsProvider)
          .createGoal(
            title: draft.title,
            kind: draft.kind,
            target: draft.target,
            unit: draft.unit,
            parent: draft.parent,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final amounts = goalAmounts(data);
    final progress = goalProgress(data, amounts);
    final view = _GoalsView(data, amounts, progress);
    final muted = TextStyle(color: Theme.of(context).colorScheme.outline);

    final active = view.rows(GoalStatus.active);
    final onHold = view.rows(GoalStatus.onHold);
    final completed = view.rows(GoalStatus.completed);

    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      appBar: AppBar(title: const Text('Goals')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (active.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No active goals', style: muted)),
            ),
          ...active,
          if (onHold.isNotEmpty)
            ExpansionTile(
              title: Text('On hold (${onHold.length})'),
              children: onHold,
            ),
          if (completed.isNotEmpty) ...[
            const SectionHeader('Completed'),
            ...completed,
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add goal',
        onPressed: () => _add(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Builds the rows of one status section as an indented tree. A goal sits
/// under its parent when both are in the same section; otherwise it is a
/// root of its section (e.g. an active sub-goal of an on-hold parent).
class _GoalsView {
  _GoalsView(this.data, this.amounts, this.progress)
    : children = childrenByParent(data.goals.values);

  final AppData data;
  final Map<String, num> amounts;
  final Map<String, double?> progress;
  final Map<String?, List<Goal>> children;

  List<Widget> rows(GoalStatus status) {
    final inSection = {
      for (final g in data.goals.values)
        if (g.status == status) g.id,
    };
    final rows = <Widget>[];
    void add(Goal goal, int depth) {
      rows.add(
        GoalRow(
          goal: goal,
          depth: depth,
          progress: progress[goal.id],
          amount: amounts[goal.id] ?? 0,
          childCount: children[goal.id]?.length ?? 0,
          logCount: goal.kind == GoalKind.log
              ? logsOf(data, goal.id).length
              : 0,
        ),
      );
      for (final child in children[goal.id] ?? const <Goal>[]) {
        if (inSection.contains(child.id)) add(child, depth + 1);
      }
    }

    final sorted = data.goals.values.toList()
      ..sort((a, b) => a.created.compareTo(b.created));
    for (final goal in sorted) {
      final parentHere =
          inSection.contains(goal.parent) &&
          children[goal.parent]!.any((c) => c.id == goal.id);
      if (goal.status == status && !parentHere) add(goal, 0);
    }
    return rows;
  }
}

class GoalRow extends StatelessWidget {
  const GoalRow({
    super.key,
    required this.goal,
    required this.depth,
    required this.progress,
    required this.amount,
    required this.childCount,
    required this.logCount,
  });

  final Goal goal;
  final int depth;
  final double? progress;
  final num amount;
  final int childCount;
  final int logCount;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 16),
      title: Text(goal.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: p.clamp(0.0, 1.0),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          const SizedBox(height: 4),
          Text(goalProgressLabel(goal, p, amount, childCount, logCount)),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GoalDetailScreen(goalId: goal.id),
        ),
      ),
    );
  }
}

/// "45 / 100 problems · 45%", "3 sub-goals · 60%", "4 log entries",
/// "Completed Wed 14 Oct".
String goalProgressLabel(
  Goal goal,
  double? progress,
  num amount,
  int childCount,
  int logCount,
) {
  final parts = <String>[
    if (goal.status == GoalStatus.completed && goal.completed != null)
      'Completed ${dayLabel(goal.completed!)} ${goal.completed!.year}',
    if (childCount > 0)
      '$childCount sub-goal${childCount == 1 ? '' : 's'}'
    else if (goal.kind == GoalKind.measurable && goal.target != null)
      '${amountLabel(amount, null)} / ${amountLabel(goal.target!, goal.unit)}'
    else if (goal.kind == GoalKind.log)
      '$logCount log entr${logCount == 1 ? 'y' : 'ies'}',
    if (progress != null) '${(progress * 100).round()}%',
  ];
  return parts.join(' · ');
}
