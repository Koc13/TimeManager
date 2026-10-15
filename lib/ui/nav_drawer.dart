import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/goal.dart';
import '../domain/period.dart';
import '../domain/progress.dart';
import '../domain/timer_state.dart';
import '../providers/data_providers.dart';
import '../providers/timer_controller.dart';
import 'format.dart';
import 'navigation.dart';
import 'noc_app_bar.dart' show countdown;
import 'theme/nocturne.dart';
import 'theme/widgets.dart';

/// Title and date, the four sections with a live note each ("4 open
/// today", "Idle"), then Settings below a rule.
class NavDrawer extends ConsumerStatefulWidget {
  const NavDrawer({super.key, required this.onSelect});

  final ValueChanged<Section> onSelect;

  @override
  ConsumerState<NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends ConsumerState<NavDrawer> {
  // Keeps the Timer note's mm:ss moving while the drawer is open.
  late final Timer _repaint = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _repaint;
  }

  @override
  void dispose() {
    _repaint.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final today = ref.watch(todayProvider);
    final selected = ref.watch(sectionProvider);
    final timer = ref.watch(timerProvider);
    final now = ref.read(clockProvider)();

    final todayDoc = data.period(Day(today));
    final openToday = todayDoc.tasks.where((t) => t.isOpen).length;
    final active = {
      for (final g in data.goals.values)
        if (g.status == GoalStatus.active) g.id,
    };
    final activeRoots = data.goals.values
        .where((g) => active.contains(g.id) && !active.contains(g.parent))
        .length;
    final habitsDone = data.habits.values
        .where((h) => habitDayValue(h, todayDoc) > 0)
        .length;

    final items = [
      (Section.todo, 'ToDo', '$openToday open today'),
      (Section.goals, 'Goals', '$activeRoots active'),
      (Section.habits, 'Habits', '$habitsDone of ${data.habits.length} today'),
      (
        Section.timer,
        'Timer',
        switch (timer?.phase) {
          null => 'Idle',
          TimerPhase.breakOffer => 'Block done',
          _ => countdown(timer!.remaining(now)),
        },
      ),
    ];

    Widget item(Section section, String label, String? note, double size) {
      final isSelected = section == selected;
      return InkWell(
        onTap: () => widget.onSelect(section),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: note == null ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Noc.accent300 : Noc.text,
                    decoration: isSelected ? TextDecoration.underline : null,
                    decorationColor: Noc.accent,
                    decorationThickness: 1,
                  ),
                ),
              ),
              if (note != null) Text(note, style: Noc.meta),
            ],
          ),
        ),
      );
    }

    return Drawer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 62, 26, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Time Manager',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                height: 1.1,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(longDayLabel(today), style: Noc.meta),
            const SizedBox(height: 22),
            const FadedRule(),
            const SizedBox(height: 8),
            for (final (section, label, note) in items)
              item(section, label, note, 19),
            const SizedBox(height: 12),
            const FadedRule(),
            const SizedBox(height: 12),
            item(Section.settings, 'Settings', null, 16),
            const Spacer(),
            const Text('Your files, in plain Markdown.', style: Noc.small),
          ],
        ),
      ),
    );
  }
}
