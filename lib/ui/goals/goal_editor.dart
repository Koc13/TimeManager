import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/progress.dart';
import '../../providers/data_providers.dart';
import '../theme/widgets.dart';

typedef GoalDraft = ({
  String title,
  GoalKind kind,
  num? target,
  String? unit,
  String? parent,
});

/// Create or edit a goal's structure (title, kind, target, parent).
/// Returns null on dismiss. Status changes live in the detail screen menu.
Future<GoalDraft?> showGoalEditor(
  BuildContext context, {
  Goal? goal,
  String? parent,
}) => showModalBottomSheet<GoalDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _GoalEditor(goal: goal, parent: parent ?? goal?.parent),
);

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({this.goal, this.parent});

  final Goal? goal;
  final String? parent;

  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late final _title = TextEditingController(text: widget.goal?.title);
  late final _target = TextEditingController(
    text: widget.goal?.target?.toString(),
  );
  late final _unit = TextEditingController(text: widget.goal?.unit);
  late GoalKind _kind = widget.goal?.kind ?? GoalKind.measurable;
  late String? _parent = widget.parent;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final target = num.tryParse(_target.text.trim());
    final unit = _unit.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Give the goal a title');
    if (_kind == GoalKind.measurable && (target == null || target <= 0)) {
      return setState(
        () => _error = 'A measurable goal needs a target above 0',
      );
    }
    Navigator.pop<GoalDraft>(context, (
      title: title,
      kind: _kind,
      target: _kind == GoalKind.measurable ? target : null,
      unit: _kind == GoalKind.measurable && unit.isNotEmpty ? unit : null,
      parent: _parent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    // A goal can't move under itself or its own sub-goals.
    final excluded = widget.goal == null
        ? <String>{}
        : subtreeIds(data, widget.goal!.id);
    final parents =
        data.goals.values.where((g) => !excluded.contains(g.id)).toList()..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

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
              autofocus: widget.goal == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Goal'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: NocSegmented<GoalKind>(
                minWidth: 96,
                options: const [
                  (GoalKind.measurable, 'Measurable'),
                  (GoalKind.log, 'Log'),
                ],
                selected: _kind,
                onChanged: (k) => setState(() => _kind = k),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _kind == GoalKind.measurable
                  ? 'Progress = everything logged ÷ target.'
                  : 'No target: a dated list of what you did. Completed by hand.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_kind == GoalKind.measurable)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _target,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Target'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'problems, pages, min',
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _parent,
              decoration: const InputDecoration(labelText: 'Part of'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— none —')),
                for (final g in parents)
                  DropdownMenuItem(value: g.id, child: Text(g.title)),
              ],
              onChanged: (v) => setState(() => _parent = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            NocButton('Save', big: true, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
