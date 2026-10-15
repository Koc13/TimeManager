import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../domain/task.dart';
import '../../domain/task_rules.dart';
import '../../providers/actions/task_actions.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';

/// Unfinished tasks offered for [day]: on today's page, what's left from
/// earlier days; on tomorrow's page (planning in the evening), what's still
/// open today. Each can be kept (moved here) or discarded (marked dropped
/// where it is, with Undo). Nothing moves without a choice.
class LeftoversCard extends ConsumerWidget {
  const LeftoversCard({super.key, required this.day});

  final Day day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final items = leftovers(ref.watch(appDataProvider), day, today);
    if (items.isEmpty) return const SizedBox.shrink();

    final actions = ref.read(taskActionsProvider);
    final planningTomorrow = day != Day(today);
    final onlyToday = items.every((i) => i.from == Day(today));

    Future<void> drop(List<({Day from, Task task})> chosen) async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      await runAction(context, () => actions.dropLeftovers(chosen));
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            chosen.length == 1
                ? 'Discarded “${chosen.single.task.title}”'
                : 'Discarded ${chosen.length} tasks',
          ),
          duration: const Duration(milliseconds: 4500),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => actions.dropLeftovers(chosen, undo: true),
          ),
        ),
      );
    }

    String fromLabel(({Day from, Task task}) item) {
      final from = item.from == Day(today)
          ? 'From today'
          : 'From ${weekdayLong(item.from.date.weekday)} '
                '${dayLabel(item.from.date).substring(4)}';
      final carried = item.task.rolledOver;
      return carried > 0 ? '$from · ↻ +$carried' : from;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: NocCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Kicker(
                    planningTomorrow && onlyToday
                        ? 'Still open today'
                        : 'Unfinished from before',
                  ),
                ),
                NocButton.ghost(
                  'Keep all',
                  small: true,
                  onPressed: () => runAction(
                    context,
                    () => actions.keepLeftovers(items, day),
                  ),
                ),
                NocButton.ghost(
                  'Discard all',
                  small: true,
                  color: Noc.neutral400,
                  onPressed: () => drop(items),
                ),
              ],
            ),
            for (final item in items)
              Ruled(
                top: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.task.title, style: Noc.secondary),
                            Text(
                              fromLabel(item),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Noc.neutral400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      NocButton(
                        'Keep',
                        small: true,
                        onPressed: () => runAction(
                          context,
                          () => actions.keepLeftovers([item], day),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NocButton.secondary(
                        'Discard',
                        small: true,
                        onPressed: () => drop([item]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
