import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../todo/done_section.dart' show SectionHeader;
import 'plan_reminder_tiles.dart';

/// App settings: where the data lives, and the plan/review reminders.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    required this.scaffoldKey,
    required this.drawer,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget drawer;

  Future<void> _changeFolder(BuildContext context, WidgetRef ref) async {
    final pick = ref.read(pickDataFolderProvider);
    final switchTo = ref.read(switchDataFolderProvider);
    final current = ref.read(dataStoreProvider).root;
    await runAction(context, () async {
      final path = await pick();
      if (path == null || path == current) return;
      await switchTo(path);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(dataStoreProvider);
    final data = ref.watch(appDataProvider);
    final muted = TextStyle(color: Theme.of(context).colorScheme.outline);
    final files =
        data.periods.length +
        data.goals.length +
        data.habits.length +
        data.recurring.length;

    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Data folder'),
            subtitle: Text(store.root),
            trailing: TextButton(
              onPressed: () => _changeFolder(context, ref),
              child: const Text('Change'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Text(
              'Pick the folder Syncthing shares. An empty folder starts '
              'fresh; this folder\'s files stay where they are.',
              style: muted,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reload files'),
            subtitle: Text(
              '$files files · loaded in '
              '${store.lastLoadTime.inMilliseconds} ms',
            ),
            onTap: () =>
                runAction(context, ref.read(appDataProvider.notifier).reload),
          ),
          const SectionHeader('Reminders'),
          const PlanReminderTiles(),
        ],
      ),
    );
  }
}
