import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/habit.dart';
import '../../domain/period.dart';
import '../../domain/progress.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../goals/goal_feedback.dart';
import 'habit_editor.dart';
import '../../providers/actions/activity_actions.dart';
import '../../providers/actions/habit_actions.dart';

const _cell = 40.0;
const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The habit grid: one row per habit, one column per day of the shown
/// week. Tap a cell to toggle (yes/no) or enter a value (measurable);
/// long-press a habit's name to edit or delete it.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({
    super.key,
    required this.scaffoldKey,
    required this.drawer,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  late Week _week = Week.containing(ref.read(todayProvider));

  List<Day> get _days => [
    for (var i = 0; i < 7; i++)
      Day(DateTime(_week.start.year, _week.start.month, _week.start.day + i)),
  ];

  Future<void> _add() async {
    final draft = await showHabitEditor(context);
    if (draft == null || !mounted) return;
    await runAction(
      context,
      () => ref
          .read(habitActionsProvider)
          .createHabit(
            title: draft.title,
            kind: draft.kind,
            unit: draft.unit,
            goal: draft.goal,
            goalAmount: draft.goalAmount,
          ),
    );
  }

  Future<void> _tapCell(Habit habit, Day day) async {
    final activity = ref.read(activityActionsProvider);
    final doc = ref.read(appDataProvider).period(day);
    final entry = doc.habitEntries
        .where((e) => e.habit == habit.id)
        .firstOrNull;
    Object? value;
    if (habit.kind == HabitKind.yesNo) {
      value = entry?.value == true ? null : true;
    } else {
      final result = await _askValue(habit, day, entry?.amount);
      if (result == null || !mounted) return;
      value = result.value;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    await runAction(context, () async {
      final reached = await activity.setHabitEntry(day, habit.id, value);
      announceReached(messenger, ref, reached);
    });
  }

  /// Returns null on cancel; `(value: null)` clears the entry.
  Future<({num? value})?> _askValue(Habit habit, Day day, num? current) {
    final text = TextEditingController(
      text: current == null ? '' : amountLabel(current, null),
    );
    final fromTimer =
        habitDayValue(habit, ref.read(appDataProvider).period(day)) -
        (current ?? 0);
    void submit(BuildContext context) {
      final v = num.tryParse(text.text.trim());
      Navigator.pop(context, (value: v == null || v == 0 ? null : v));
    }

    return showDialog<({num? value})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${habit.title} · ${dayLabel(day.date)}'),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            suffixText: habit.unit,
            helperText: fromTimer > 0
                ? '+ ${amountLabel(fromTimer, habit.unit)} from the timer'
                : null,
          ),
          onSubmitted: (_) => submit(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => submit(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _habitMenu(Habit habit) async {
    final data = ref.read(habitActionsProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              subtitle: const Text('Past entries stay in your history'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'edit') {
      final draft = await showHabitEditor(context, habit: habit);
      if (draft == null || !mounted) return;
      await runAction(
        context,
        () => data.saveHabit(
          habit.copyWith(
            title: draft.title,
            kind: draft.kind,
            unit: draft.unit,
            goal: draft.goal,
            goalAmount: draft.goalAmount,
          ),
        ),
      );
    } else if (choice == 'delete') {
      await runAction(context, () => data.deleteHabit(habit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final today = ref.watch(todayProvider);
    final habits = data.habits.values.toList()
      ..sort((a, b) => a.created.compareTo(b.created));
    final scheme = Theme.of(context).colorScheme;
    final days = _days;

    return Scaffold(
      key: widget.scaffoldKey,
      drawer: widget.drawer,
      appBar: AppBar(
        title: Text(
          'Week ${_week.week} · ${dayLabel(_week.start).substring(4)}',
        ),
        actions: [
          IconButton(
            tooltip: 'Previous week',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _week = _week.previous),
          ),
          IconButton(
            tooltip: 'Next week',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _week = _week.next),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 96),
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              for (final (i, day) in days.indexed)
                SizedBox(
                  width: _cell,
                  child: Column(
                    children: [
                      Text(_weekdayLetters[i]),
                      Text(
                        '${day.date.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: day.date == today
                              ? FontWeight.bold
                              : null,
                          color: day.date == today
                              ? scheme.primary
                              : scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No habits yet',
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            ),
          for (final habit in habits)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onLongPress: () => _habitMenu(habit),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        habit.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                for (final day in days)
                  _Cell(
                    habit: habit,
                    value: habitDayValue(habit, data.period(day)),
                    isToday: day.date == today,
                    // Logging the future makes no sense; the past is fine.
                    onTap: day.date.isAfter(today)
                        ? null
                        : () => _tapCell(habit, day),
                  ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add habit',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.habit,
    required this.value,
    required this.isToday,
    required this.onTap,
  });

  final Habit habit;
  final num value;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = value > 0;
    return SizedBox(
      width: _cell,
      height: _cell,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: filled
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(
                  alpha: onTap == null ? 0.3 : 1,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isToday
                ? BorderSide(color: scheme.primary, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Center(
              child: !filled
                  ? null
                  : habit.kind == HabitKind.yesNo
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: scheme.onPrimaryContainer,
                    )
                  : FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          amountLabel(value, null),
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
