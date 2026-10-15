import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data_providers.dart';
import '../feedback.dart';
import '../noc_app_bar.dart';
import '../theme/nocturne.dart';
import '../theme/widgets.dart';
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
    final files =
        data.periods.length +
        data.goals.length +
        data.habits.length +
        data.recurring.length;

    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      appBar: NocAppBar(scaffoldKey: scaffoldKey, title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Noc.gutter, 22, Noc.gutter, 40),
        children: [
          const Kicker('Data folder'),
          const SizedBox(height: 10),
          NocCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.root, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '$files files · loaded in '
                  '${(store.lastLoadTime.inMilliseconds / 1000).toStringAsFixed(2)} s',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0x80E9E9ED),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    NocButton(
                      'Change',
                      small: true,
                      onPressed: () => _changeFolder(context, ref),
                    ),
                    const SizedBox(width: 8),
                    NocButton.secondary(
                      'Reload files',
                      small: true,
                      onPressed: () => runAction(context, () async {
                        await ref.read(appDataProvider.notifier).reload();
                        if (context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(content: Text('Files reloaded')),
                          );
                        }
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pick the folder Syncthing shares. An empty folder starts fresh; '
            'this folder\'s files stay where they are.',
            style: Noc.meta,
          ),
          const SizedBox(height: 34),
          const Kicker('Reminders'),
          const SizedBox(height: 6),
          const PlanReminderTiles(),
        ],
      ),
    );
  }
}
