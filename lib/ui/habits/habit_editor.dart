import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/habit.dart';
import '../../providers/data_providers.dart';
import '../theme/widgets.dart';

typedef HabitDraft = ({
  String title,
  HabitKind kind,
  String? unit,
  String? goal,
  num goalAmount,
});

Future<HabitDraft?> showHabitEditor(BuildContext context, {Habit? habit}) =>
    showModalBottomSheet<HabitDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HabitEditor(habit: habit),
    );

class _HabitEditor extends ConsumerStatefulWidget {
  const _HabitEditor({this.habit});

  final Habit? habit;

  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  late final _title = TextEditingController(text: widget.habit?.title);
  late final _unit = TextEditingController(text: widget.habit?.unit);
  late final _goalAmount = TextEditingController(
    text: '${widget.habit?.goalAmount ?? 1}',
  );
  late HabitKind _kind = widget.habit?.kind ?? HabitKind.yesNo;
  late String? _goal = widget.habit?.goal;

  @override
  void dispose() {
    _title.dispose();
    _unit.dispose();
    _goalAmount.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final unit = _unit.text.trim();
    Navigator.pop<HabitDraft>(context, (
      title: title,
      kind: _kind,
      unit: _kind == HabitKind.measurable && unit.isNotEmpty ? unit : null,
      goal: _goal,
      goalAmount: num.tryParse(_goalAmount.text.trim()) ?? 1,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final goals =
        ref
            .watch(appDataProvider)
            .goals
            .values
            // Keep the current link selectable even if that goal is done.
            .where((g) => g.status != GoalStatus.completed || g.id == _goal)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.habit == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Habit'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: NocSegmented<HabitKind>(
                minWidth: 96,
                options: const [
                  (HabitKind.yesNo, 'Yes / no'),
                  (HabitKind.measurable, 'Measurable'),
                ],
                selected: _kind,
                onChanged: (k) => setState(() => _kind = k),
              ),
            ),
            if (_kind == HabitKind.measurable)
              TextField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  hintText: 'pages, minutes',
                  helperText: 'Use "minutes" to count timer sessions too',
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _goal,
              decoration: const InputDecoration(
                labelText: 'Counts toward goal',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— none —')),
                for (final g in goals)
                  DropdownMenuItem(value: g.id, child: Text(g.title)),
              ],
              onChanged: (v) => setState(() => _goal = v),
            ),
            if (_goal != null && _kind == HabitKind.yesNo)
              TextField(
                controller: _goalAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(labelText: 'Each check adds'),
              ),
            const SizedBox(height: 16),
            NocButton('Save', big: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
