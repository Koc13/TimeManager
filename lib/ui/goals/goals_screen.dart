import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_data.dart';
import '../../domain/goal.dart';
import '../../domain/progress.dart';
import '../../providers/actions/goal_actions.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../noc_app_bar.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import 'goal_detail_screen.dart';
import 'goal_editor.dart';
import '../theme/icons.dart';

/// Active goals as an indented tree with progress bars, then On hold
/// (collapsed) and Completed: one scroll.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({
    super.key,
    required this.scaffoldKey,
    required this.drawer,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showOnHold = false;

  Future<void> _add() async {
    final draft = await showGoalEditor(context);
    if (draft == null || !mounted) return;
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
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final view = GoalsView(data);
    final active = view.rows(GoalStatus.active);
    final onHold = view.rows(GoalStatus.onHold);
    final completed =
        data.goals.values
            .where((g) => g.status == GoalStatus.completed)
            .toList()
          ..sort(
            (a, b) =>
                (b.completed ?? b.created).compareTo(a.completed ?? a.created),
          );

    return Scaffold(
      key: widget.scaffoldKey,
      drawer: widget.drawer,
      appBar: NocAppBar(scaffoldKey: widget.scaffoldKey, title: 'Goals'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Noc.gutter, 22, Noc.gutter, 40),
        children: [
          Kicker('Active · ${active.where((r) => r.depth == 0).length}'),
          const SizedBox(height: 6),
          for (final row in active) GoalRow(row: row),
          if (active.isEmpty)
            const Ruled(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Text(
                  'No active goals.',
                  style: TextStyle(fontSize: 15, color: Noc.neutral400),
                ),
              ),
            ),
          Ruled(
            child: InkWell(
              onTap: _add,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Icon(Ph.plus, size: 22, color: Noc.accent300),
                    SizedBox(width: 14),
                    Text(
                      'Add a goal',
                      style: TextStyle(fontSize: 15, color: Noc.accent300),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onHold.isNotEmpty) ...[
            const SizedBox(height: 36),
            InkWell(
              onTap: () => setState(() => _showOnHold = !_showOnHold),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Kicker(
                      'On hold · ${onHold.where((r) => r.depth == 0).length}',
                      color: Noc.neutral400,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _showOnHold ? Ph.caretUp : Ph.caretDown,
                      size: 12,
                      color: Noc.neutral400,
                    ),
                  ],
                ),
              ),
            ),
            if (_showOnHold) ...[
              const SizedBox(height: 6),
              for (final row in onHold) GoalRow(row: row),
            ],
          ],
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 36),
            Kicker('Completed · ${completed.length}', color: Noc.neutral400),
            const SizedBox(height: 6),
            for (final goal in completed)
              Ruled(
                child: InkWell(
                  onTap: () => openGoal(context, goal.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Ph.check, size: 14, color: Noc.accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                [
                                  if (goal.completed != null)
                                    'Completed ${goal.completed!.day} '
                                        '${monthName(goal.completed!.month)}',
                                  if (data.goals[goal.parent] case final p?)
                                    'part of ${p.title}',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Noc.neutral400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

void openGoal(BuildContext context, String id) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => GoalDetailScreen(goalId: id)));

/// One row of the goal tree, precomputed.
typedef GoalRowData = ({Goal goal, int depth, double? progress, String amount});

/// Builds a status section's rows as an indented tree. A goal sits under
/// its parent when both are in the same section; otherwise it is a root of
/// its section (e.g. an active sub-goal of an on-hold parent).
class GoalsView {
  GoalsView(this.data)
    : children = childrenByParent(data.goals.values),
      amounts = goalAmounts(data) {
    progress = goalProgress(data, amounts);
  }

  final AppData data;
  final Map<String?, List<Goal>> children;
  final Map<String, num> amounts;
  late final Map<String, double?> progress;

  List<GoalRowData> rows(GoalStatus status) {
    final inSection = {
      for (final g in data.goals.values)
        if (g.status == status) g.id,
    };
    final rows = <GoalRowData>[];
    void add(Goal goal, int depth) {
      rows.add((
        goal: goal,
        depth: depth,
        progress: progress[goal.id],
        amount: amountText(goal),
      ));
      for (final child in children[goal.id] ?? const <Goal>[]) {
        if (inSection.contains(child.id)) add(child, depth + 1);
      }
    }

    final sorted = data.goals.values.toList()
      ..sort((a, b) => a.created.compareTo(b.created));
    for (final goal in sorted) {
      if (goal.status == status && !inSection.contains(goal.parent)) {
        add(goal, 0);
      }
    }
    return rows;
  }

  /// "38,400 of 60,000 words", "21 h 30 min of 30 h",
  /// "1 of 2 sub-goals complete", "Log goal · 4 entries".
  String amountText(Goal goal) {
    final kids = children[goal.id] ?? const <Goal>[];
    if (kids.isNotEmpty) {
      final done = kids.where((k) => k.status == GoalStatus.completed).length;
      return '$done of ${kids.length} sub-goal${kids.length == 1 ? '' : 's'} complete';
    }
    if (goal.kind == GoalKind.log) {
      final n = logsOf(data, goal.id).length;
      return n == 0 ? 'Log goal' : 'Log goal · $n entr${n == 1 ? 'y' : 'ies'}';
    }
    final amount = amounts[goal.id] ?? 0;
    final target = goal.target;
    if (target == null) return groupThousands(amount);
    if (isMinutes(goal.unit)) {
      return '${minutesLabel(amount.round())} of ${minutesLabel(target.round())}';
    }
    final unit = goal.unit == null ? '' : ' ${goal.unit}';
    return '${groupThousands(amount)} of ${groupThousands(target)}$unit';
  }
}

class GoalRow extends StatelessWidget {
  const GoalRow({super.key, required this.row});

  final GoalRowData row;

  @override
  Widget build(BuildContext context) {
    final p = row.progress;
    return Ruled(
      child: InkWell(
        onTap: () => openGoal(context, row.goal.id),
        child: Padding(
          padding: EdgeInsets.fromLTRB(row.depth * 18.0, 16, 0, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      row.goal.title,
                      style: TextStyle(
                        fontSize: row.depth == 0 ? 16 : 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (p != null)
                    Text(
                      '${(p * 100).round()}%',
                      style: Noc.title.copyWith(
                        color: Noc.accent300,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              if (p != null) ...[
                const SizedBox(height: 10),
                NocProgress(value: p, thick: true),
              ],
              const SizedBox(height: 7),
              Text(row.amount, style: Noc.meta),
            ],
          ),
        ),
      ),
    );
  }
}
