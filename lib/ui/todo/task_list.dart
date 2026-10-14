import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../domain/task.dart';
import '../../domain/task_rules.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import 'task_editor.dart';

/// One period's open tasks. Checked tasks leave the list (they go to the
/// period's Done page).
class TaskList extends ConsumerWidget {
  const TaskList({super.key, required this.period});

  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(appDataProvider.select((d) => d.period(period)));
    final open = openTasksSorted(doc.tasks);
    final done = doc.tasks.length - open.length;
    final muted = TextStyle(color: Theme.of(context).colorScheme.outline);

    return ListView(
      // Room for the FAB below the last row.
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Nothing to do', style: muted)),
          ),
        for (final task in open) TaskTile(period: period, task: task),
        if (done > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('$done done', style: muted)),
          ),
      ],
    );
  }
}

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.period, required this.task});

  final Period period;
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final now = ref.read(clockProvider)();
    final deadline = task.deadline;
    final overdue = deadline != null && deadline.isBefore(now);

    final details = [
      if (deadline != null)
        (overdue ? 'Overdue · ' : 'Due ') + dateTimeLabel(deadline),
      if (task.rolledOver > 0) '↻ ${task.rolledOver}',
    ];

    return ListTile(
      leading: Checkbox(
        value: task.isDone,
        onChanged: (done) => runAction(
          context,
          () => ref.read(appDataProvider.notifier).setDone(period, task, done!),
        ),
      ),
      title: Text(task.title),
      subtitle: details.isEmpty
          ? null
          : Text(
              details.join('  ·  '),
              style: overdue ? TextStyle(color: scheme.error) : null,
            ),
      trailing: _PriorityMark(priority: task.priority),
      onLongPress: () => showTaskActions(context, ref, period, task),
    );
  }
}

class _PriorityMark extends StatelessWidget {
  const _PriorityMark({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (priority) {
      1 => Icon(Icons.keyboard_double_arrow_up, color: scheme.error, size: 20),
      3 => Icon(Icons.keyboard_arrow_down, color: scheme.outline, size: 20),
      _ => const SizedBox.shrink(),
    };
  }
}
