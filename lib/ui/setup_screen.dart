import 'package:flutter/material.dart';

import '../storage/data_store.dart';
import '../storage/local_settings.dart';
import 'data_folder.dart';
import 'theme/widgets.dart';
import 'theme/nocturne.dart';
import 'theme/icons.dart';

/// First run (or a folder that can no longer be opened): pick the data
/// root folder and get permission to read it.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.settings,
    required this.onOpened,
    this.initialError,
  });

  final LocalSettings settings;
  final ValueChanged<DataStore> onOpened;
  final String? initialError;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late String? _error = widget.initialError;
  bool _busy = false;

  Future<void> _choose() async {
    setState(() => _busy = true);
    try {
      final path = await pickDataFolder();
      if (path == null) return;
      final store = await DataStore.open(path);
      await widget.settings.setDataRoot(path);
      widget.onOpened(store);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Time Manager', style: text.headlineMedium),
              const SizedBox(height: 12),
              const Text(
                'Choose a folder for your data. Everything is stored there '
                'as Markdown files, so you can sync it with Syncthing and '
                'read it in Obsidian. An empty folder starts fresh; a folder '
                'used before keeps its data.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Noc.accent200)),
              ],
              const SizedBox(height: 24),
              NocButton(
                'Choose data folder',
                big: true,
                icon: Ph.folderOpen,
                onPressed: _busy ? null : _choose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
