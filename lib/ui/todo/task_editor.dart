import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/goal.dart';
import '../../domain/period.dart';
import '../../domain/recurring.dart';
import '../../domain/target_ref.dart';
import '../../domain/task.dart';
import '../../domain/task_rules.dart';
import '../../providers/actions/task_actions.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import '../theme/icons.dart';

/// What the task sheet returns. [repeat] is only offered for new tasks;
/// when set, the caller creates a recurring template instead of a task.
typedef TaskDraft = ({
  String title,
  int priority,
  DateTime? deadline,
  DateTime? reminder,
  RepeatRule? repeat,
});

/// "New task · Today" (or "Edit task"). Returns null on dismiss.
Future<TaskDraft?> showTaskEditor(
  BuildContext context, {
  Task? task,
  String? listName,
}) => showModalBottomSheet<TaskDraft>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _TaskEditor(task: task, listName: listName),
);

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, this.listName});

  final Task? task;
  final String? listName;

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
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

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
      isScrollControlled: true,
      builder: (context) => _SheetList(
        title: 'Repeat',
        rows: [
          for (final (label, value) in [
            ('Never', 'never'),
            ('Every day', const RepeatRule.daily()),
            ('On chosen weekdays…', 'weekdays'),
            ('Every week (weekly list)', const RepeatRule.weekly()),
            ('Every month (monthly list)', const RepeatRule.monthly()),
            ('Monthly on a day…', 'monthday'),
          ])
            (label, () => Navigator.pop(context, value), null),
        ],
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
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                _Chip(
                  label: weekdayShort(d),
                  on: days.contains(d),
                  onTap: () => setDialog(
                    () => days.contains(d) ? days.remove(d) : days.add(d),
                  ),
                ),
            ],
          ),
          actions: [
            NocButton.secondary(
              'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
            NocButton(
              'OK',
              onPressed: () => Navigator.pop(context, days.isNotEmpty),
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
          NocButton.secondary(
            'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          NocButton(
            'OK',
            onPressed: () {
              final d = int.tryParse(text.text.trim());
              if (d != null && d >= 1 && d <= 31) Navigator.pop(context, d);
            },
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
        22,
        0,
        22,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isNew ? 'New task · ${widget.listName ?? ''}' : 'Edit task',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(hintText: 'What needs doing?'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          const Text('Priority', style: Noc.meta),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: NocSegmented<int>(
              options: const [(1, 'High'), (2, 'Normal'), (3, 'Low')],
              selected: _priority,
              onChanged: (p) => setState(() => _priority = p),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_isNew)
                _Chip(
                  label: _repeat == null
                      ? 'Repeat'
                      : '↻ ${repeatShort(_repeat!)}',
                  on: repeating,
                  onTap: _pickRepeat,
                  onClear: repeating
                      ? () => setState(() => _repeat = null)
                      : null,
                ),
              if (!repeating)
                _Chip(
                  label: _deadline == null
                      ? 'Deadline'
                      : 'Due ${dateTimeLabel(_deadline!)}',
                  on: _deadline != null,
                  onTap: () async {
                    final v = await _pickDateTime(_deadline);
                    if (v != null) setState(() => _deadline = v);
                  },
                  onClear: _deadline == null
                      ? null
                      : () => setState(() => _deadline = null),
                ),
              _Chip(
                label: _reminder == null
                    ? 'Reminder'
                    : repeating
                    ? 'Reminder ${timeLabel(_reminder!)}'
                    : 'Reminder ${dateTimeLabel(_reminder!)}',
                on: _reminder != null,
                onTap: () async {
                  final v = await _pickDateTime(_reminder, timeOnly: repeating);
                  if (v != null) setState(() => _reminder = v);
                },
                onClear: _reminder == null
                    ? null
                    : () => setState(() => _reminder = null),
              ),
            ],
          ),
          const SizedBox(height: 22),
          NocButton(
            _isNew ? 'Add task' : 'Save',
            big: true,
            onPressed: _title.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// A sheet chip: divider edge when off, accent edge with its value when
/// on; an on chip can be cleared with its ×.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: EdgeInsets.fromLTRB(12, 6, onClear == null ? 12 : 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: on ? Noc.accent : Noc.divider),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: on ? Noc.accent300 : Noc.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onClear,
              child: const Icon(Ph.x, size: 14, color: Noc.neutral400),
            ),
          ],
        ],
      ),
    ),
  );
}

/// A bottom sheet with a title, an optional subtitle and ruled text rows.
/// Each row is (label, onTap, colour).
class _SheetList extends StatelessWidget {
  const _SheetList({required this.title, this.subtitle, required this.rows});

  final String title;
  final String? subtitle;
  final List<(String, VoidCallback, Color?)> rows;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Noc.meta),
          ],
          const SizedBox(height: 12),
          for (final (label, onTap, color) in rows)
            Ruled(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: color ?? Noc.text),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The task's action sheet (tap a task row).
Future<void> showTaskActions(
  BuildContext context,
  WidgetRef ref,
  Period period,
  Task task,
) async {
  final actions = ref.read(taskActionsProvider);
  final data = ref.read(appDataProvider);
  final today = ref.read(todayProvider);
  final now = ref.read(clockProvider)();
  final messenger = ScaffoldMessenger.maybeOf(context);

  String moveLabel(PeriodKind kind) {
    final target = moveTarget(period, kind, now);
    final isNow = target == Period.of(kind, today);
    return switch (kind) {
      PeriodKind.day =>
        isNow ? 'Move to today' : 'Move to ${listLabel(target, today)}',
      PeriodKind.week =>
        isNow ? 'Move to this week' : 'Move to ${listLabel(target, today)}',
      PeriodKind.month =>
        isNow ? 'Move to this month' : 'Move to ${listLabel(target, today)}',
    };
  }

  final nextWord = switch (period.kind) {
    PeriodKind.day =>
      period == Day(today) ? 'tomorrow' : dayLabel(period.next.start),
    PeriodKind.week => 'next week',
    PeriodKind.month => 'next month',
  };
  final link = task.link;
  final series =
      task.recurring != null && data.recurring.containsKey(task.recurring);

  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetList(
      title: task.title,
      subtitle: 'In ${listLabel(period, today)}',
      rows: [
        ('Edit', () => Navigator.pop(context, 'edit'), null),
        (
          'Postpone to $nextWord',
          () => Navigator.pop(context, 'postpone'),
          null,
        ),
        for (final kind in PeriodKind.values)
          if (kind != period.kind)
            (
              moveLabel(kind),
              () => Navigator.pop(context, 'move:${kind.name}'),
              null,
            ),
        (
          link == null
              ? 'Link to goal or habit'
              : 'Linked → ${targetName(data, link)}',
          () => Navigator.pop(context, 'link'),
          null,
        ),
        if (series)
          ('Stop repeating', () => Navigator.pop(context, 'stop'), null),
        ('Delete', () => Navigator.pop(context, 'delete'), Noc.accent300),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;

  void snack(String text, [VoidCallback? undo]) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 4500),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
  }

  switch (choice) {
    case 'edit':
      final draft = await showTaskEditor(context, task: task);
      if (draft == null || !context.mounted) return;
      await runAction(
        context,
        () => actions.saveTask(
          period,
          task.copyWith(
            title: draft.title,
            priority: draft.priority,
            deadline: draft.deadline,
            reminder: draft.reminder,
          ),
        ),
      );
    case 'postpone':
      await runAction(context, () => actions.postpone(period, task));
      snack('Moved to $nextWord');
    case 'link':
      final picked = await showLinkPicker(context, ref, current: link);
      if (picked == null || !context.mounted) return;
      await runAction(
        context,
        () => actions.saveTask(period, task.copyWith(link: picked.target)),
      );
    case 'stop':
      await runAction(context, () => actions.deleteRecurring(task.recurring!));
      snack('Stopped repeating');
    case 'delete':
      await runAction(context, () => actions.deleteTask(period, task.id));
      snack('Task deleted', () => actions.saveTask(period, task));
    default:
      if (choice.startsWith('move:')) {
        final kind = PeriodKind.values.byName(choice.substring(5));
        await runAction(context, () => actions.moveTask(period, task, kind));
      }
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
    isScrollControlled: true,
    builder: (context) => _SheetList(
      title: 'Link to goal or habit',
      subtitle: goals.isEmpty && habits.isEmpty
          ? 'No goals or habits yet'
          : null,
      rows: [
        if (current != null)
          (
            'Remove link',
            () => Navigator.pop(context, (target: null)),
            Noc.accent300,
          ),
        for (final g in goals)
          (
            '${g.title}${current == TargetRef.goal(g.id) ? '  ✓' : ''}',
            () => Navigator.pop(context, (target: TargetRef.goal(g.id))),
            null,
          ),
        for (final h in habits)
          (
            '${h.title}${current == TargetRef.habit(h.id) ? '  ✓' : ''}',
            () => Navigator.pop(context, (target: TargetRef.habit(h.id))),
            null,
          ),
      ],
    ),
  );
}
