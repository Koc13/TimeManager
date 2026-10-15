import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../domain/task.dart';
import '../../domain/task_rules.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';

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

    final data = ref.read(appDataProvider.notifier);
    final theme = Theme.of(context);
    final planningTomorrow = day != Day(today);
    final onlyToday = items.every((i) => i.from == Day(today));

    Future<void> drop(List<({Day from, Task task})> chosen) async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      await runAction(context, () => data.dropLeftovers(chosen));
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            chosen.length == 1
                ? 'Discarded "${chosen.single.task.title}"'
                : 'Discarded ${chosen.length} tasks',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => data.dropLeftovers(chosen, undo: true),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    planningTomorrow && onlyToday
                        ? 'Still open today (${items.length})'
                        : 'Unfinished from before (${items.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => drop(items),
                  child: const Text('Discard all'),
                ),
                TextButton(
                  onPressed: () =>
                      runAction(context, () => data.keepLeftovers(items, day)),
                  child: const Text('Keep all'),
                ),
              ],
            ),
          ),
          for (final item in items)
            ListTile(
              dense: true,
              title: Text(item.task.title),
              subtitle: item.from == Day(today)
                  ? null
                  : Text(dayLabel(item.from.date)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Discard',
                    icon: const Icon(Icons.close),
                    onPressed: () => drop([item]),
                  ),
                  IconButton(
                    tooltip: 'Keep',
                    icon: const Icon(Icons.add),
                    onPressed: () => runAction(
                      context,
                      () => data.keepLeftovers([item], day),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
