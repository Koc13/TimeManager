import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/period.dart';
import '../../domain/task.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import 'task_editor.dart';

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

    final link = task.link;
    final details = [
      if (link != null) '→ ${targetName(ref.watch(appDataProvider), link)}',
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
