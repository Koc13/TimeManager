import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/habit.dart';
import '../../domain/period.dart';
import '../../domain/progress.dart';
import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../format.dart';
import '../noc_app_bar.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';

import '../goals/goal_feedback.dart';
import 'habit_editor.dart';
import '../../providers/actions/activity_actions.dart';
import '../../providers/actions/habit_actions.dart';
import '../theme/icons.dart';

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
        title: Text(habit.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${weekdayLong(day.date.weekday)}. Leave empty or 0 to clear the day.',
            ),
            const SizedBox(height: 12),
            Text(
              _capitalised(habit.unit ?? 'Amount'),
              style: const TextStyle(fontSize: 12, color: Color(0xB3E9E9ED)),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: text,
              autofocus: true,
              style: const TextStyle(
                fontSize: 16,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                helperText: fromTimer > 0
                    ? '+ ${amountLabel(fromTimer, habit.unit)} from the timer'
                    : null,
              ),
              onSubmitted: (_) => submit(context),
            ),
          ],
        ),
        actions: [
          NocButton.secondary(
            'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          NocButton('Save', onPressed: () => submit(context)),
        ],
      ),
    );
  }

  Future<void> _habitMenu(Habit habit) async {
    final data = ref.read(habitActionsProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                habit.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              for (final (label, value, color) in const [
                ('Edit', 'edit', Noc.text),
                (
                  'Delete (past entries stay in your history)',
                  'delete',
                  Noc.accent300,
                ),
              ])
                Ruled(
                  child: InkWell(
                    onTap: () => Navigator.pop(context, value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 15, color: color),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
    final days = _days;
    final thisWeek = Week.containing(today);

    return Scaffold(
      key: widget.scaffoldKey,
      drawer: widget.drawer,
      appBar: NocAppBar(scaffoldKey: widget.scaffoldKey, title: 'Habits'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(periodKicker(_week, today)),
                      const SizedBox(height: 4),
                      Text('Week ${_week.week}', style: Noc.displaySmall),
                      const SizedBox(height: 4),
                      Text(
                        periodSub(_week),
                        style: Noc.meta.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Previous week',
                  icon: const Icon(Ph.caretLeft, size: 20),
                  onPressed: () => setState(() => _week = _week.previous),
                ),
                IconButton(
                  tooltip: 'Next week',
                  icon: const Icon(Ph.caretRight, size: 20),
                  onPressed: () => setState(() => _week = _week.next),
                ),
              ],
            ),
          ),
          if (_week != thisWeek)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NocButton.ghost(
                  '← Back to this week',
                  small: true,
                  onPressed: () => setState(() => _week = thisWeek),
                ),
              ),
            ),
          const SizedBox(height: 22),
          Ruled(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Opacity(
                        opacity: day.date.isAfter(today) ? 0.4 : 1,
                        child: Column(
                          children: [
                            Text(
                              weekdayShort(day.date.weekday)
                                  .substring(0, 2)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                color: Noc.neutral400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(Noc.rSm),
                                border: Border.all(
                                  color: day.date == today
                                      ? Noc.accent
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                '${day.date.day}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (habits.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 22, 6, 0),
              child: Text(
                'No habits yet.',
                style: TextStyle(fontSize: 15, color: Noc.neutral400),
              ),
            ),
          for (final habit in habits)
            _HabitRow(
              habit: habit,
              values: [
                for (final day in days) habitDayValue(habit, data.period(day)),
              ],
              days: days,
              today: today,
              onTap: _tapCell,
              onMenu: () => _habitMenu(habit),
            ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: _Legend(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 10, 6, 0),
            child: Text(
              'Tap a day to check it off. Numbers open a dialog. Days after '
              'today stay closed. Long-press a habit to edit it.',
              style: Noc.meta,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Ruled(
              top: true,
              child: InkWell(
                onTap: _add,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Icon(Ph.plus, size: 22, color: Noc.accent300),
                      SizedBox(width: 14),
                      Text(
                        'Add a habit',
                        style: TextStyle(fontSize: 15, color: Noc.accent300),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalised(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// One habit: name, the week's total, then seven heat cells.
class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.values,
    required this.days,
    required this.today,
    required this.onTap,
    required this.onMenu,
  });

  final Habit habit;
  final List<num> values;
  final List<Day> days;
  final DateTime today;
  final void Function(Habit, Day) onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final measurable = habit.kind == HabitKind.measurable;
    // No per-day target is stored, so the week's best day sets the scale
    // (as the design suggests); derived, never saved.
    final scale = values.fold<num>(0, (a, b) => b > a ? b : a);
    final total = measurable
        ? amountLabel(values.fold<num>(0, (a, b) => a + b), habit.unit)
        : '${values.where((v) => v > 0).length} of 7';

    return Ruled(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
        child: Column(
          children: [
            InkWell(
              onLongPress: onMenu,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        habit.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(total, style: Noc.meta),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, day) in days.indexed)
                  Expanded(
                    child: Center(
                      child: HeatCell(
                        semanticLabel:
                            '${habit.title} ${weekdayShort(day.date.weekday)}',
                        level: measurable
                            ? levelFor(values[i], scale)
                            : (values[i] > 0 ? 4 : 0),
                        check: !measurable && values[i] > 0,
                        label: measurable && values[i] > 0
                            ? amountLabel(values[i], null)
                            : null,
                        isToday: day.date == today,
                        enabled: !day.date.isAfter(today),
                        onTap: () => onTap(habit, day),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, color: Noc.neutral400);
    return Row(
      children: [
        const Text('Less', style: style),
        const SizedBox(width: 8),
        for (var level = 0; level <= 4; level++) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Noc.heat[level],
              borderRadius: BorderRadius.circular(Noc.rSm),
              border: level == 0 ? Border.all(color: Noc.neutral800) : null,
            ),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        const Text('More', style: style),
      ],
    );
  }
}
