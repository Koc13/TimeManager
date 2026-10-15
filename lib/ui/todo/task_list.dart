import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/period.dart';
import '../../domain/task.dart';
import '../../providers/actions/task_actions.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import 'task_editor.dart';

/// An open task: checkbox, title with a High/Low tag, and a meta line
/// ("Due today · Reminder 14:00 · ↻ Daily · Carried +1 · → Goal").
/// Tapping the box completes it (with Undo); tapping the row opens its
/// action sheet.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.period, required this.task});

  final Period period;
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final now = ref.read(clockProvider)();
    final today = midnight(now);
    final deadline = task.deadline;
    final overdue = deadline != null && deadline.isBefore(now);
    final template = task.recurring == null
        ? null
        : data.recurring[task.recurring];

    final meta = [
      if (deadline != null)
        midnight(deadline) == today ? 'Due today' : 'Due ${dayLabel(deadline)}',
      if (task.reminder case final r? when r.isAfter(now))
        'Reminder ${timeLabel(r)}',
      if (template != null) '↻ ${repeatShort(template.rule)}',
      if (task.rolledOver > 0) 'Carried +${task.rolledOver}',
      if (task.link case final link?) '→ ${targetName(data, link)}',
    ];

    Future<void> complete() async {
      final actions = ref.read(taskActionsProvider);
      final messenger = ScaffoldMessenger.maybeOf(context);
      await runAction(context, () => actions.setDone(period, task, true));
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: const Text('Done'),
          duration: const Duration(milliseconds: 4500),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => actions.setDone(period, task, false),
          ),
        ),
      );
    }

    return Ruled(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(-11, 0),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: NocCheckbox(
                checked: false,
                onTap: complete,
                semanticLabel: 'Complete',
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => showTaskActions(context, ref, period, task),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 13, 0, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(task.title, style: Noc.body)),
                        if (task.priority != 2) ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: NocTag(
                              task.priority == 1 ? 'High' : 'Low',
                              accent: task.priority == 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (meta.isNotEmpty || overdue)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text.rich(
                          TextSpan(
                            text: meta.join(' · '),
                            children: [
                              if (overdue)
                                TextSpan(
                                  text: meta.isEmpty ? 'Overdue' : ' · Overdue',
                                  style: const TextStyle(color: Noc.accent200),
                                ),
                            ],
                          ),
                          style: Noc.meta,
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
