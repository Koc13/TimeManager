import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/period.dart';
import '../../providers/actions/task_actions.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';

/// Below the list: what got done in this period (from any list, plus
/// discarded leftovers), then session time per target, then habit entries
/// and goal logs. All derived.
class DoneSection extends ConsumerWidget {
  const DoneSection({super.key, required this.period});

  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final today = ref.watch(todayProvider);
    final done = doneTasks(data, period);
    final dropped = [
      for (final t in data.period(period).tasks)
        if (t.droppedAt != null) t,
    ];
    final activity = activityIn(data, period);
    final singleDay = period.kind == PeriodKind.day;

    Widget line(String left, String right) => Ruled(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(left, style: Noc.secondary)),
            const SizedBox(width: 10),
            Text(
              right,
              style: Noc.secondary.copyWith(
                color: Noc.neutral300,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Done', count: '${done.length}'),
        const SizedBox(height: 6),
        for (final (:list, :task) in done)
          Ruled(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(-11, 0),
                  child: NocCheckbox(
                    checked: true,
                    semanticLabel: 'Mark open',
                    onTap: () => runAction(
                      context,
                      () => ref
                          .read(taskActionsProvider)
                          .setDone(list, task, false),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Noc.neutral400,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Noc.neutral600,
                          ),
                        ),
                        if (list != period)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'from ${listLabel(list, today)}',
                              style: Noc.small,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final task in dropped)
          Ruled(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    child: Text(
                      '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Noc.neutral600),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Noc.neutral500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  const Text('Discarded', style: Noc.small),
                ],
              ),
            ),
          ),
        if (done.isEmpty && dropped.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nothing finished yet.',
              style: TextStyle(fontSize: 13, color: Noc.neutral500),
            ),
          ),
        if (activity.sessions.isNotEmpty) ...[
          const SizedBox(height: 34),
          const SectionTitle('Time'),
          const SizedBox(height: 6),
          for (final s in activity.sessions)
            line(targetName(data, s.target), minutesLabel(s.minutes)),
        ],
        // Habit entries and goal logs ("Other" activity).
        if (activity.habits.isNotEmpty || activity.goalLogs.isNotEmpty) ...[
          const SizedBox(height: 34),
          const SectionTitle('Logged'),
          const SizedBox(height: 6),
          for (final h in activity.habits)
            line(
              data.habits[h.habit]?.title ?? '(deleted habit)',
              habitAmount(data.habits[h.habit], h, singleDay: singleDay),
            ),
          for (final log in activity.goalLogs)
            line(
              [
                data.goals[log.goal]?.title ?? '(deleted goal)',
                if (log.source != null) log.source!,
              ].join(' · '),
              log.amount == null ? '' : amountLabel(log.amount!, log.unit),
            ),
        ],
        const SizedBox(height: 34),
      ],
    );
  }
}
