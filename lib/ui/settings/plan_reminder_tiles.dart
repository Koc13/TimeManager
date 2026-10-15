import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../domain/plan_reminders.dart';
import '../../providers/plan_reminders.dart';
import '../feedback.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import '../theme/icons.dart';

/// One row per plan/review reminder: switch to turn it on or off, tap to
/// change when it fires.
class PlanReminderTiles extends ConsumerWidget {
  const PlanReminderTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(planRemindersProvider);
    final controller = ref.read(planRemindersProvider.notifier);
    return Column(
      children: [
        for (final reminder in PlanReminder.values)
          Ruled(
            child: InkWell(
              onTap: () async {
                final time = await showDialog<ReminderTime>(
                  context: context,
                  builder: (_) => _ReminderEditor(
                    reminder: reminder,
                    time: settings[reminder]!,
                  ),
                );
                if (time != null && context.mounted) {
                  await runAction(
                    context,
                    () => controller.set(reminder, time),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: settings[reminder]!.enabled ? 1 : 0.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: const TextStyle(fontSize: 15),
                            ),
                            Text(
                              scheduleLabel(reminder, settings[reminder]!),
                              style: Noc.meta,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    NocSwitch(
                      value: settings[reminder]!.enabled,
                      onChanged: (on) => runAction(
                        context,
                        () => controller.set(
                          reminder,
                          settings[reminder]!.copyWith(enabled: on),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Every day · 08:00", "Sundays · 20:00", "Last day · 20:00", "1st · 08:00".
String scheduleLabel(PlanReminder reminder, ReminderTime time) {
  final at = _clock(time.minute);
  return switch (reminder.kind) {
    PeriodKind.day => 'Every day · $at',
    PeriodKind.week => '${weekdayLong(time.weekday)}s · $at',
    PeriodKind.month =>
      time.monthDay == lastDay
          ? 'Last day · $at'
          : '${_ordinal(time.monthDay)} · $at',
  };
}

String _ordinal(int n) => switch (n) {
  1 || 21 => '${n}st',
  2 || 22 => '${n}nd',
  3 || 23 => '${n}rd',
  _ => '${n}th',
};

String _clock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({required this.reminder, required this.time});

  final PlanReminder reminder;
  final ReminderTime time;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late ReminderTime _time = widget.time;

  @override
  Widget build(BuildContext context) {
    final kind = widget.reminder.kind;
    return AlertDialog(
      title: Text(widget.reminder.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kind == PeriodKind.week)
            DropdownButtonFormField<int>(
              initialValue: _time.weekday,
              decoration: const InputDecoration(labelText: 'Day'),
              items: [
                for (var d = 1; d <= 7; d++)
                  DropdownMenuItem(value: d, child: Text(weekdayLong(d))),
              ],
              onChanged: (d) =>
                  setState(() => _time = _time.copyWith(weekday: d)),
            ),
          if (kind == PeriodKind.month)
            DropdownButtonFormField<int>(
              initialValue: _time.monthDay,
              decoration: const InputDecoration(labelText: 'Day of the month'),
              items: [
                for (var d = 1; d <= 28; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
                const DropdownMenuItem(value: lastDay, child: Text('Last day')),
              ],
              onChanged: (d) =>
                  setState(() => _time = _time.copyWith(monthDay: d)),
            ),
          const SizedBox(height: 12),
          NocButton.secondary(
            _clock(_time.minute),
            icon: Ph.clock,
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _time.minute ~/ 60,
                  minute: _time.minute % 60,
                ),
              );
              if (picked != null) {
                setState(
                  () => _time = _time.copyWith(
                    minute: picked.hour * 60 + picked.minute,
                  ),
                );
              }
            },
          ),
        ],
      ),
      actions: [
        NocButton.secondary('Cancel', onPressed: () => Navigator.pop(context)),
        NocButton('Save', onPressed: () => Navigator.pop(context, _time)),
      ],
    );
  }
}
