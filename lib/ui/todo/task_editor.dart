import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
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
    case 'delete':
      await runAction(context, () => data.deleteTask(period, task.id));
    case final PeriodKind kind:
      await runAction(context, () => data.moveTask(period, task, kind));
  }
}
