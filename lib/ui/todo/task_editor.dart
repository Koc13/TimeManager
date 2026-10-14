import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/period.dart';
import '../../domain/target_ref.dart';
import '../../domain/task.dart';
import '../../providers/data_providers.dart';
import '../../domain/recurring.dart';
import '../feedback.dart';
import '../format.dart';

/// What the task sheet returns. [repeat] is only offered for new tasks;
/// when set, the caller creates a recurring template instead of a task.
typedef TaskDraft = ({
  String title,
  int priority,
  DateTime? deadline,
  DateTime? reminder,
  RepeatRule? repeat,
});

/// Bottom sheet for a task. Returns null on dismiss.
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
  late DateTime? _deadline = widget.task?.deadline;
  late DateTime? _reminder = widget.task?.reminder;
  RepeatRule? _repeat;

  bool get _isNew => widget.task == null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop<TaskDraft>(context, (
      title: title,
      priority: _priority,
      // A series has no deadline; its reminder is a time of day.
      deadline: _repeat == null ? _deadline : null,
      reminder: _reminder,
      repeat: _repeat,
    ));
  }

  Future<DateTime?> _pickDateTime(
    DateTime? current, {
    bool timeOnly = false,
  }) async {
    final now = DateTime.now();
    final base = current ?? DateTime(now.year, now.month, now.day, 18);
    var date = base;
    if (!timeOnly) {
      final picked = await showDatePicker(
        context: context,
        initialDate: base,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null || !mounted) return null;
      date = picked;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickRepeat() async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (label, value) in [
              ('Never', 'never'),
              ('Every day', const RepeatRule.daily()),
              ('On chosen weekdays…', 'weekdays'),
              ('Every week (weekly list)', const RepeatRule.weekly()),
              ('Every month (monthly list)', const RepeatRule.monthly()),
              ('Monthly on a day…', 'monthday'),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final RepeatRule? rule = switch (choice) {
      'never' => null,
      'weekdays' => await _pickWeekdays(),
      'monthday' => await _pickMonthDay(),
      final RepeatRule r => r,
      _ => _repeat,
    };
    setState(() => _repeat = rule);
  }

  Future<RepeatRule?> _pickWeekdays() async {
    final days = <int>{DateTime.now().weekday};
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Repeat on'),
          content: Wrap(
            spacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(weekdayShort(d)),
                  selected: days.contains(d),
                  onSelected: (on) =>
                      setDialog(() => on ? days.add(d) : days.remove(d)),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, days.isNotEmpty),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    return ok == true ? RepeatRule.weekdays(days) : _repeat;
  }

  Future<RepeatRule?> _pickMonthDay() async {
    final text = TextEditingController(text: '${DateTime.now().day}');
    final day = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Day of the month'),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            helperText: '31 means the last day in shorter months',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final d = int.tryParse(text.text.trim());
              if (d != null && d >= 1 && d <= 31) Navigator.pop(context, d);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return day == null ? _repeat : RepeatRule.monthly(day);
  }

  @override
  Widget build(BuildContext context) {
    final repeating = _repeat != null;
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
            autofocus: _isNew,
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (!repeating)
                _DateChip(
                  icon: Icons.event,
                  label: 'Deadline',
                  value: _deadline == null ? null : dateTimeLabel(_deadline!),
                  onPick: () async {
                    final v = await _pickDateTime(_deadline);
                    if (v != null) setState(() => _deadline = v);
                  },
                  onClear: () => setState(() => _deadline = null),
                ),
              _DateChip(
                icon: Icons.notifications_outlined,
                label: 'Reminder',
                value: _reminder == null
                    ? null
                    : repeating
                    ? 'at ${timeLabel(_reminder!)}'
                    : dateTimeLabel(_reminder!),
                onPick: () async {
                  final v = await _pickDateTime(_reminder, timeOnly: repeating);
                  if (v != null) setState(() => _reminder = v);
                },
                onClear: () => setState(() => _reminder = null),
              ),
              if (_isNew)
                ActionChip(
                  avatar: const Icon(Icons.repeat, size: 18),
                  label: Text(repeatLabel(_repeat)),
                  onPressed: _pickRepeat,
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => value == null
      ? ActionChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: onPick,
        )
      : InputChip(
          avatar: Icon(icon, size: 18),
          label: Text(value!),
          onPressed: onPick,
          onDeleted: onClear,
        );
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
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
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
          if (task.recurring != null &&
              ref.read(appDataProvider).recurring.containsKey(task.recurring))
            ListTile(
              leading: const Icon(Icons.repeat_on_outlined),
              title: const Text('Stop repeating'),
              subtitle: const Text('This task stays; no new ones are created'),
              onTap: () => Navigator.pop(context, 'stop'),
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
          task.copyWith(
            title: draft.title,
            priority: draft.priority,
            deadline: draft.deadline,
            reminder: draft.reminder,
          ),
        ),
      );
    case 'link':
      final link = await showLinkPicker(context, ref, current: task.link);
      if (link == null || !context.mounted) return;
      await runAction(
        context,
        () => data.saveTask(period, task.copyWith(link: link.target)),
      );
    case 'stop':
      await runAction(context, () => data.deleteRecurring(task.recurring!));
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
