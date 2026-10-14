import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/folder_watcher.dart';
import 'data_providers.dart';

/// Reloads the data when files change on disk (Syncthing, Obsidian). The
/// shell listens to this so the watcher lives as long as the app.
final folderWatchProvider = Provider<FolderWatcher>((ref) {
  late final FolderWatcher watcher;
  watcher = FolderWatcher(ref.read(dataStoreProvider).root, (paths) async {
    try {
      final reloaded = await ref
          .read(appDataProvider.notifier)
          .reloadIfChanged(paths);
      // Pick up folders created since the last scan.
      if (reloaded) await watcher.start();
    } catch (_) {
      // The resume reload is the fallback; a failed refresh isn't fatal.
    }
  });
  watcher.start();
  ref.onDispose(watcher.stop);
  return watcher;
});
