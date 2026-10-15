import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';
import '../providers/data_providers.dart';
import '../providers/folder_watch.dart';
import '../providers/reminder_sync.dart';
import '../providers/timer_controller.dart';
import 'goals/goal_feedback.dart';
import 'feedback.dart';
import 'goals/goals_screen.dart';
import 'habits/habits_screen.dart';
import 'settings/settings_screen.dart';
import 'timer/timer_screen.dart';
import 'todo/todo_pager.dart';
import '../providers/actions/task_actions.dart';

enum Section { todo, timer, goals, habits, settings }

/// Switches between the four drawer sections and owns app-wide timing:
/// rollover and recurring tasks on start, at midnight, and on resume (after reloading files,
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
  // A cold start opens the Daily ToDo, or the Timer while a work block or
  // break is running or waiting at its break offer. Coming back from the
  // background keeps whatever section was open (this state survives).
  late Section _section = ref.read(timerProvider) == null
      ? Section.todo
      : Section.timer;
  Timer? _midnight;
  StreamSubscription<String>? _taps;

  /// The visible section's Scaffold. Only one section is mounted at a time,
  /// so one key is enough; the shell uses it to open/close the drawer.
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _dayCheck());
    // Tapping the timer's notification jumps to the Timer; a reminder
    // jumps to the ToDo.
    _taps = ref.read(notificationsProvider).taps.listen((payload) {
      if (!mounted) return;
      _scaffold.currentState?.closeDrawer();
      setState(
        () => _section = payload == timerPayload ? Section.timer : Section.todo,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      runAction(context, () async {
        await ref.read(appDataProvider.notifier).reload();
        await _dayCheck();
        // The timer may have ended while the app was in the background.
        await ref.read(timerProvider.notifier).tick();
      });
    }
  }

  Future<void> _dayCheck() async {
    ref.read(todayProvider.notifier).refresh();
    _scheduleMidnight();
    await runAction(context, ref.read(taskActionsProvider).startDay);
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
    // Goals completed by a timer session that ended off-screen.
    ref.listen(reachedGoalsProvider, (_, reached) {
      announceReached(ScaffoldMessenger.maybeOf(context), ref, reached);
    });
    // Listened to here so the timer is restored at start-up (and can finish
    // a block that ended while the app was dead) without rebuilding the
    // shell on every timer change.
    ref.listen(timerProvider, (_, _) {});
    // Keeps scheduled reminders in line with the tasks on disk.
    ref.listen(reminderSyncProvider, (_, _) {});
    // Reloads when Syncthing or Obsidian change files while the app is open.
    ref.listen(folderWatchProvider, (_, _) {});
    final issues = ref.watch(storeIssuesProvider);
    final hasIssues =
        issues.conflicts.isNotEmpty || issues.unreadable.isNotEmpty;
    final drawer = AppDrawer(selected: _section, onSelect: _go);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: _WithIssues(
        show: hasIssues,
        child: switch (_section) {
          Section.todo => TodoPager(scaffoldKey: _scaffold, drawer: drawer),
          Section.timer => TimerScreen(scaffoldKey: _scaffold, drawer: drawer),
          Section.goals => GoalsScreen(scaffoldKey: _scaffold, drawer: drawer),
          Section.habits => HabitsScreen(
            scaffoldKey: _scaffold,
            drawer: drawer,
          ),
          Section.settings => SettingsScreen(
            scaffoldKey: _scaffold,
            drawer: drawer,
          ),
        },
      ),
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
      // Below a divider: the four sections are the app; this configures it.
      (Section.settings, Icons.settings_outlined, 'Settings'),
    ];
    return NavigationDrawer(
      selectedIndex: items.indexWhere((i) => i.$1 == selected),
      onDestinationSelected: (i) => onSelect(items[i].$1),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text('Time Manager'),
        ),
        for (final (section, icon, label) in items) ...[
          if (section == Section.settings)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Divider(),
            ),
          NavigationDrawerDestination(icon: Icon(icon), label: Text(label)),
        ],
      ],
    );
  }
}

/// A warning strip above every section while the data folder has Syncthing
/// conflict copies or files that couldn't be read. It stays until
/// the files are fixed, since the app can't fix them itself.
class _WithIssues extends StatelessWidget {
  const _WithIssues({required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Column(
      children: [
        const IssuesBanner(),
        // The section's own app bar must not add the status-bar inset again.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class IssuesBanner extends ConsumerWidget {
  const IssuesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:conflicts, :unreadable) = ref.watch(storeIssuesProvider);
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      if (conflicts.isNotEmpty)
        '${conflicts.length} sync conflict${conflicts.length == 1 ? '' : 's'}',
      if (unreadable.isNotEmpty)
        '${unreadable.length} unreadable file${unreadable.length == 1 ? '' : 's'}',
    ];
    return Material(
      color: scheme.errorContainer,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Check these files'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (conflicts.isNotEmpty) ...[
                    const Text(
                      'Syncthing kept two versions of these. Merge what you '
                      'need into the original file and delete the conflict '
                      'copy. The app ignores conflict copies.',
                    ),
                    const SizedBox(height: 8),
                    for (final path in conflicts) SelectableText('• $path'),
                    const SizedBox(height: 16),
                  ],
                  if (unreadable.isNotEmpty) ...[
                    const Text(
                      'These could not be read, so the app will not write to '
                      'them until they are fixed in a text editor:',
                    ),
                    const SizedBox(height: 8),
                    for (final MapEntry(key: path, value: error)
                        in unreadable.entries)
                      SelectableText('• $path\n   $error'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  runAction(context, ref.read(appDataProvider.notifier).reload);
                },
                child: const Text('Reload'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
        // The colour runs under the status bar; the content stays below it.
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${parts.join(' and ')} in your data folder',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
