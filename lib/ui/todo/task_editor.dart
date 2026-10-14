import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/period.dart';
import '../../domain/target_ref.dart';
import '../../domain/task.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';

typedef TaskDraft = ({String title, int priority});

/// Bottom sheet for a task's title and priority. Returns null on dismiss.
Future<TaskDraft?> showTaskEditor(BuildContext context, {Task? task}) =>
    showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true, // lets the sheet rise above the keyboard
      showDragHandle: true,
      builder: (_) => _TaskEditor(task: task),
    );

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task});

  final Task? task;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title);
  late int _priority = widget.task?.priority ?? 2;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop<TaskDraft>(context, (title: title, priority: _priority));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Task'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('High')),
              ButtonSegment(value: 2, label: Text('Medium')),
              ButtonSegment(value: 3, label: Text('Low')),
            ],
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.single),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

/// Long-press menu: edit, move to another list, delete.
Future<void> showTaskActions(
  BuildContext context,
  WidgetRef ref,
  Period period,
  Task task,
) async {
  final data = ref.read(appDataProvider.notifier);
  const kindLabels = {
    PeriodKind.day: 'Move to daily list',
    PeriodKind.week: 'Move to weekly list',
    PeriodKind.month: 'Move to monthly list',
  };
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () => Navigator.pop(context, 'edit'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(
              task.link == null ? 'Link to goal or habit' : 'Change link',
            ),
            onTap: () => Navigator.pop(context, 'link'),
          ),
          for (final MapEntry(key: kind, value: label) in kindLabels.entries)
            if (kind != period.kind)
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: Text(label),
                onTap: () => Navigator.pop(context, kind),
              ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete'),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'edit':
      final draft = await showTaskEditor(context, task: task);
      if (draft == null || !context.mounted) return;
      await runAction(
        context,
        () => data.saveTask(
          period,
          task.copyWith(title: draft.title, priority: draft.priority),
        ),
      );
    case 'link':
      final link = await showLinkPicker(context, ref, current: task.link);
      if (link == null || !context.mounted) return;
      await runAction(
        context,
        () => data.saveTask(period, task.copyWith(link: link.target)),
      );
    case 'delete':
      await runAction(context, () => data.deleteTask(period, task.id));
    case final PeriodKind kind:
      await runAction(context, () => data.moveTask(period, task, kind));
  }
}

/// Picks a goal or habit for a task's informational link. Returns null when
/// dismissed, or a record whose `target` is null for "remove the link".
Future<({TargetRef? target})?> showLinkPicker(
  BuildContext context,
  WidgetRef ref, {
  TargetRef? current,
}) {
  final data = ref.read(appDataProvider);
  final goals =
      data.goals.values.where((g) => g.status != GoalStatus.completed).toList()
        ..sort((a, b) => a.title.compareTo(b.title));
  final habits = data.habits.values.toList()
    ..sort((a, b) => a.title.compareTo(b.title));
  return showModalBottomSheet<({TargetRef? target})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          if (current != null)
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Remove link'),
              onTap: () => Navigator.pop(context, (target: null)),
            ),
          if (goals.isEmpty && habits.isEmpty)
            const ListTile(title: Text('No goals or habits yet')),
          for (final g in goals)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(g.title),
              selected: current == TargetRef.goal(g.id),
              onTap: () =>
                  Navigator.pop(context, (target: TargetRef.goal(g.id))),
            ),
          for (final h in habits)
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(h.title),
              selected: current == TargetRef.habit(h.id),
              onTap: () =>
                  Navigator.pop(context, (target: TargetRef.habit(h.id))),
            ),
        ],
      ),
    ),
  );
}
