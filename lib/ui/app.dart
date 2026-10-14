import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
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
  const TimeManagerApp({super.key, required this.settings});

  final LocalSettings settings;

  @override
  State<TimeManagerApp> createState() => _TimeManagerAppState();
}

class _TimeManagerAppState extends State<TimeManagerApp> {
  DataStore? _store;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openRemembered();
  }

  Future<void> _openRemembered() async {
    final root = await widget.settings.dataRoot();
    if (root != null) {
      try {
        _store = await DataStore.open(root);
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
      overrides: [dataStoreProvider.overrideWithValue(store)],
      child: app,
    );
  }
}
