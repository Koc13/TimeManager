import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';

/// Placeholder until the ToDo pager.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(dataStoreProvider);
    final data = ref.watch(appDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Time Manager')),
      body: ListTile(
        title: Text(store.root),
        subtitle: Text(
          '${data.periods.length} periods, ${data.goals.length} goals, '
          '${data.habits.length} habits',
        ),
      ),
    );
  }
}
