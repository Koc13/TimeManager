import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/goal.dart';
import '../theme/widgets.dart';

typedef LogDraft = ({num? amount, String? unit, String? source});

/// Asks for one goal log entry. A measurable goal needs an amount in its
/// own unit; a log goal takes a source plus an optional quantity
/// ("Bishop", 25 pages).
Future<LogDraft?> showLogDialog(BuildContext context, Goal goal) =>
    showDialog<LogDraft>(
      context: context,
      builder: (_) => _LogDialog(goal: goal),
    );

class _LogDialog extends StatefulWidget {
  const _LogDialog({required this.goal});

  final Goal goal;

  @override
  State<_LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<_LogDialog> {
  final _amount = TextEditingController();
  late final _unit = TextEditingController(text: widget.goal.unit);
  final _source = TextEditingController();

  bool get _measurable => widget.goal.kind == GoalKind.measurable;

  @override
  void dispose() {
    _amount.dispose();
    _unit.dispose();
    _source.dispose();
    super.dispose();
  }

  void _save() {
    final amount = num.tryParse(_amount.text.trim());
    final source = _source.text.trim();
    final unit = _unit.text.trim();
    if (_measurable ? amount == null : (source.isEmpty && amount == null)) {
      return;
    }
    Navigator.pop<LogDraft>(context, (
      amount: amount,
      unit: unit.isEmpty ? null : unit,
      source: source.isEmpty ? null : source,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final amountField = TextField(
      controller: _amount,
      autofocus: _measurable,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: 'Amount',
        suffixText: _measurable ? widget.goal.unit : null,
      ),
      onSubmitted: (_) => _save(),
    );
    return AlertDialog(
      title: Text('Log: ${widget.goal.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _source,
            autofocus: !_measurable,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _measurable ? 'Note (optional)' : 'Source',
              hintText: _measurable ? null : 'Pattern Recognition (Bishop)',
            ),
          ),
          if (_measurable)
            amountField
          else
            Row(
              children: [
                Expanded(child: amountField),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      hintText: 'pages, %, min',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        NocButton.secondary('Cancel', onPressed: () => Navigator.pop(context)),
        NocButton('Log', onPressed: _save),
      ],
    );
  }
}
