import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/period.dart';
import '../../domain/task_rules.dart';
import '../../providers/data_providers.dart';
import 'done_section.dart';
import 'journal_editor.dart';
import 'task_list.dart';

/// One period's ToDo list with its Done page below it.
///
/// Why one scroll view instead of a vertical PageView: two nested
/// scrollables on the same axis don't hand a drag from one to the other, so
/// "scroll past the end of the list" would stop at the list's end. Here the
/// ToDo part is simply made at least one screen tall, so the Done page
/// starts just below the fold and the same scroll reaches it.
class PeriodPage extends ConsumerWidget {
  const PeriodPage({super.key, required this.period});

  final Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(appDataProvider.select((d) => d.period(period)));
    final open = openTasksSorted(doc.tasks);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.outline);

    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (open.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text('Nothing to do', style: muted),
                        ),
                      ),
                    for (final task in open)
                      TaskTile(period: period, task: task),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 88, top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Done', style: muted),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: scheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: DoneSection(period: period)),
          SliverToBoxAdapter(child: JournalEditor(period: period)),
          // Room for the FAB below the editor.
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
