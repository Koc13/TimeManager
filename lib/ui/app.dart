import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/timer_state.dart';
import '../notifications/notification_service.dart';
import '../providers/data_providers.dart';
import '../providers/plan_reminders.dart';
import '../providers/timer_controller.dart';
import '../storage/data_store.dart';
import '../storage/local_settings.dart';
import 'app_shell.dart';
import 'theme/nocturne.dart';
import 'data_folder.dart';
import 'setup_screen.dart';

/// Opens the data folder remembered on this device, or asks for one.
///
/// Why the ProviderScope sits *above* MaterialApp and is only created once
/// a folder is open: routes and dialogs are pushed above `home`, so a scope
/// placed under MaterialApp would be invisible to them; and creating it
/// late lets every provider assume a [DataStore] exists.
class TimeManagerApp extends StatefulWidget {
  const TimeManagerApp({
    super.key,
    required this.settings,
    required this.notifications,
    this.pickFolder = pickDataFolder,
  });

  final LocalSettings settings;
  final Notifications notifications;

  /// The system folder picker; tests pass a stand-in.
  final Future<String?> Function() pickFolder;

  @override
  State<TimeManagerApp> createState() => _TimeManagerAppState();
}

class _TimeManagerAppState extends State<TimeManagerApp> {
  DataStore? _store;
  TimerState? _timer;
  Object? _planReminders;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openRemembered();
  }

  /// Opens [path] (throws if it can't be used), remembers it on this device
  /// and rebuilds the app on it. The timer and reminders are device-local,
  /// so they carry over; the reminder sync reconciles against the new data.
  Future<void> _switchTo(String path) async {
    final store = await DataStore.open(path);
    await widget.settings.setDataRoot(path);
    final timer = TimerState.fromJson(await widget.settings.timer());
    final planReminders = await widget.settings.planReminders();
    setState(() {
      _store = store;
      _timer = timer;
      _planReminders = planReminders;
    });
  }

  Future<void> _openRemembered() async {
    _timer = TimerState.fromJson(await widget.settings.timer());
    _planReminders = await widget.settings.planReminders();
    final root = await widget.settings.dataRoot();
    if (root != null) {
      try {
        _store = await DataStore.open(root);
        debugPrint('Loaded $root in ${_store!.lastLoadTime.inMilliseconds} ms');
      } catch (e) {
        _error = 'Could not open $root: $e';
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final home = _loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : store == null
        ? SetupScreen(
            settings: widget.settings,
            initialError: _error,
            onOpened: (opened) => setState(() => _store = opened),
          )
        : const AppShell();
    final app = MaterialApp(
      title: 'Time Manager',
      // One dark theme, per the Nocturne design.
      theme: nocturneTheme(),
      home: home,
    );
    if (store == null) return app;
    return ProviderScope(
      key: ObjectKey(store),
      overrides: [
        dataStoreProvider.overrideWithValue(store),
        localSettingsProvider.overrideWithValue(widget.settings),
        notificationsProvider.overrideWithValue(widget.notifications),
        restoredTimerProvider.overrideWithValue(_timer),
        restoredPlanRemindersProvider.overrideWithValue(_planReminders),
        switchDataFolderProvider.overrideWithValue(_switchTo),
        pickDataFolderProvider.overrideWithValue(widget.pickFolder),
      ],
      child: app,
    );
  }
}
