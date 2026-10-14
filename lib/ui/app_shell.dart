import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import 'feedback.dart';
import 'goals/goals_screen.dart';
import 'todo/todo_pager.dart';

enum Section { todo, timer, goals, habits }

/// Switches between the four drawer sections and owns app-wide timing:
/// rollover on start, at midnight, and on resume (after reloading files,
/// since Syncthing or Obsidian may have changed them while we were away).
///
/// Sections are swapped in place rather than pushed as routes, so every
/// section shows the menu icon (not a back arrow) and Android's back button
/// returns to the ToDo instead of stacking screens.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  Section _section = Section.todo;
  Timer? _midnight;

  /// The visible section's Scaffold. Only one section is mounted at a time,
  /// so one key is enough; the shell uses it to open/close the drawer.
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _dayCheck());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      runAction(context, () async {
        await ref.read(appDataProvider.notifier).reload();
        await _dayCheck();
      });
    }
  }

  Future<void> _dayCheck() async {
    ref.read(todayProvider.notifier).refresh();
    _scheduleMidnight();
    await runAction(context, ref.read(appDataProvider.notifier).rollover);
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = ref.read(clockProvider)();
    final next = DateTime(now.year, now.month, now.day + 1);
    // A few seconds late so "now" is safely in the new day.
    _midnight = Timer(next.difference(now) + const Duration(seconds: 2), () {
      if (mounted) _dayCheck();
    });
  }

  void _go(Section section) {
    _scaffold.currentState?.closeDrawer();
    setState(() => _section = section);
  }

  // Back is always claimed (canPop: false) and resolved here, in order:
  // close the drawer, leave a non-ToDo section, exit the app.
  //
  // Why not canPop: true at the ToDo? With Android's predictive back,
  // Flutter tells the OS it handles Back only if something can pop, and an
  // open drawer doesn't count, so the OS closed the app with the drawer
  // open. And since canPop: false also blocks the drawer's own pop (a
  // route checks PopScope before its local history), the drawer is closed
  // explicitly instead.
  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    final scaffold = _scaffold.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else if (_section != Section.todo) {
      setState(() => _section = Section.todo);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = AppDrawer(selected: _section, onSelect: _go);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: switch (_section) {
        Section.todo => TodoPager(scaffoldKey: _scaffold, drawer: drawer),
        Section.timer => _NotYet(
          scaffoldKey: _scaffold,
          drawer: drawer,
          title: 'Timer',
          milestone: 7,
        ),
        Section.goals => GoalsScreen(scaffoldKey: _scaffold, drawer: drawer),
        Section.habits => _NotYet(
          scaffoldKey: _scaffold,
          drawer: drawer,
          title: 'Habits',
          milestone: 6,
        ),
      },
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.selected, required this.onSelect});

  final Section selected;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Section.todo, Icons.checklist, 'ToDo'),
      (Section.timer, Icons.timer_outlined, 'Timer'),
      (Section.goals, Icons.flag_outlined, 'Goals'),
      (Section.habits, Icons.repeat, 'Habits'),
    ];
    return NavigationDrawer(
      selectedIndex: items.indexWhere((i) => i.$1 == selected),
      onDestinationSelected: (i) => onSelect(items[i].$1),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text('Time Manager'),
        ),
        for (final (_, icon, label) in items)
          NavigationDrawerDestination(icon: Icon(icon), label: Text(label)),
      ],
    );
  }
}

class _NotYet extends StatelessWidget {
  const _NotYet({
    required this.scaffoldKey,
    required this.drawer,
    required this.title,
    required this.milestone,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;
  final String title;
  final int milestone;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffoldKey,
    drawer: drawer,
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text('Coming soon')),
  );
}
