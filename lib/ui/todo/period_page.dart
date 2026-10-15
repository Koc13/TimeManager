import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregation.dart';
import '../../domain/period.dart';
import '../../domain/task_rules.dart';
import '../../providers/data_providers.dart';
import '../format.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
import 'done_section.dart';
import 'journal_editor.dart';
import 'leftovers_card.dart';
import 'task_list.dart';
import '../theme/icons.dart';

/// One period's page: header, progress, leftovers, open tasks with an
/// "Add a task" row, then Done, Time, Logged and the journal, in one
/// scroll.
class PeriodPage extends ConsumerWidget {
  const PeriodPage({
    super.key,
    required this.period,
    required this.onShow,
    required this.onAdd,
  });

  final Period period;

  /// Switches this page to another period (arrows, date picker, "Back").
  final ValueChanged<Period> onShow;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final today = ref.watch(todayProvider);
    final doc = data.period(period);
    final open = openTasksSorted(doc.tasks);
    final doneCount = doneTasks(data, period).length;
    final total = open.length + doneCount;
    final current = Period.of(period.kind, today);
    final isCurrent = period == current;

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: period.start,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked != null) onShow(Period.of(period.kind, picked));
    }

    final emptyText = switch (period) {
      Day() when period.compareTo(current) < 0 => 'Nothing was left open.',
      Day() => 'A clear page.',
      _ => 'Nothing planned yet.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Noc.gutter, 22, Noc.gutter, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(periodKicker(period, today)),
                  const SizedBox(height: 4),
                  Text(periodHeading(period), style: Noc.display),
                  const SizedBox(height: 4),
                  Text(
                    periodSub(period),
                    style: Noc.meta.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Previous',
              icon: const Icon(Ph.caretLeft, size: 20),
              onPressed: () => onShow(period.previous),
            ),
            IconButton(
              tooltip: 'Next',
              icon: const Icon(Ph.caretRight, size: 20),
              onPressed: () => onShow(period.next),
            ),
            IconButton(
              tooltip: 'Go to date',
              icon: const Icon(Ph.calendarBlank, size: 20),
              onPressed: pickDate,
            ),
          ],
        ),
        if (!isCurrent)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: NocButton.ghost(
                '← Back to ${switch (period.kind) {
                  PeriodKind.day => 'today',
                  PeriodKind.week => 'this week',
                  PeriodKind.month => 'this month',
                }}',
                small: true,
                onPressed: () => onShow(current),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: NocProgress(value: total == 0 ? 0 : doneCount / total),
            ),
            const SizedBox(width: 10),
            Text(
              total == 0 ? 'No tasks' : '$doneCount of $total done',
              style: Noc.meta,
            ),
          ],
        ),
        if (period case final Day day) LeftoversCard(day: day),
        const SizedBox(height: 14),
        for (final task in open) TaskTile(period: period, task: task),
        if (open.isEmpty)
          Ruled(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                emptyText,
                style: const TextStyle(fontSize: 15, color: Noc.neutral400),
              ),
            ),
          ),
        Ruled(
          child: InkWell(
            onTap: onAdd,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: [
                  Icon(Ph.plus, size: 22, color: Noc.accent300),
                  SizedBox(width: 14),
                  Text(
                    'Add a task',
                    style: TextStyle(fontSize: 15, color: Noc.accent300),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        DoneSection(period: period),
        JournalEditor(period: period),
      ],
    );
  }
}
