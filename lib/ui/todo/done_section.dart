import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/period.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';

/// The period's Done page: tasks completed in it (from any list), then
/// "Other" activity from the timer and trackers. Everything is derived.
class DoneSection extends ConsumerWidget {
  const DoneSection({super.key, required this.period});

  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final done = doneTasks(data, period);
    final activity = activityIn(data, period);
    final muted = TextStyle(color: Theme.of(context).colorScheme.outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Done'),
        if (done.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Nothing completed yet', style: muted),
          ),
        for (final (:list, :task) in done)
          ListTile(
            dense: true,
            leading: Checkbox(
              value: true,
              onChanged: (_) => runAction(
                context,
                () => ref
                    .read(appDataProvider.notifier)
                    .setDone(list, task, false),
              ),
            ),
            title: Text(task.title),
            subtitle: Text(
              [
                timeLabel(task.doneAt!),
                if (list != period) 'from ${periodLabel(list)}',
              ].join('  ·  '),
            ),
          ),
        const SectionHeader('Other'),
        if (activity.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No sessions, habits or logs', style: muted),
          ),
        for (final s in activity.sessions)
          _Line(
            icon: Icons.timer_outlined,
            text:
                '${targetName(data, s.target)}: ${minutesLabel(s.minutes)}, '
                '${s.count} session${s.count == 1 ? '' : 's'}',
          ),
        for (final h in activity.habits)
          _Line(
            icon: Icons.repeat,
            text: habitSummary(
              data.habits[h.habit],
              h,
              singleDay: period.kind == PeriodKind.day,
            ),
          ),
        for (final log in activity.goalLogs)
          _Line(
            icon: Icons.flag_outlined,
            text: [
              data.goals[log.goal]?.title ?? '(deleted goal)',
              if (log.amount != null) amountLabel(log.amount!, log.unit),
              if (log.source != null) log.source!,
            ].join(' · '),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
