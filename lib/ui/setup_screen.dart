import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/data_store.dart';
import '../storage/local_settings.dart';

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
      // Android: the folder is in shared storage (so Syncthing can sync it)
      // and is read with plain dart:io, which needs "All files access".
      if (Platform.isAndroid &&
          !await Permission.manageExternalStorage.request().isGranted) {
        setState(() => _error = 'Allow "All files access" to use a folder.');
        return;
      }
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: 'Data folder',
      );
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
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _choose,
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose data folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
