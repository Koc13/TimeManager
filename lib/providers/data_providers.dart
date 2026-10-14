import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_data.dart';
import '../storage/data_store.dart';

/// The opened data folder. Always overridden in the ProviderScope that
/// app.dart creates once a folder is open, so everything below it can
/// assume one exists.
final dataStoreProvider = Provider<DataStore>(
  (ref) => throw StateError('dataStoreProvider must be overridden'),
);

/// The in-memory data set. Every change goes through this controller:
/// it writes the files first, then publishes the store's new state, so the
/// UI never shows something that isn't on disk.
final appDataProvider = NotifierProvider<AppDataController, AppData>(
  AppDataController.new,
);

class AppDataController extends Notifier<AppData> {
  DataStore get _store => ref.read(dataStoreProvider);

  @override
  AppData build() => ref.watch(dataStoreProvider).data;

  Future<void> reload() async {
    await _store.reload();
    state = _store.data;
  }
}
