import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/timer_state.dart';
import '../notifications/notification_service.dart';
import '../providers/data_providers.dart';
import '../providers/timer_controller.dart';
import '../storage/data_store.dart';
import '../storage/local_settings.dart';
import 'app_shell.dart';
import 'setup_screen.dart';

const _seed = Color(0xFF0A84FF);

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
);

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
  });

  final LocalSettings settings;
  final Notifications notifications;

  @override
  State<TimeManagerApp> createState() => _TimeManagerAppState();
}

class _TimeManagerAppState extends State<TimeManagerApp> {
  DataStore? _store;
  TimerState? _timer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openRemembered();
  }

  Future<void> _openRemembered() async {
    _timer = TimerState.fromJson(await widget.settings.timer());
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
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
      ],
      child: app,
    );
  }
}
