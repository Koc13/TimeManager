import 'dart:async';
import 'dart:io';

/// Reports files changed under a folder, debounced.
///
/// Why one watch per folder: `Directory.watch(recursive: true)` only
/// reports the top folder on Linux/Android (checked on this machine), so
/// each folder is watched on its own. [start] is called again after every
/// reload so folders created since (a new month) are watched too.
///
/// On Android, changes made by other apps (Syncthing) may or may not reach
/// the watcher through the shared-storage layer; the reload on resume is
/// the guaranteed path, this is the faster one.
class FolderWatcher {
  FolderWatcher(this.root, this.onChange);

  final String root;
  final void Function(Set<String> paths) onChange;

  final _subscriptions = <StreamSubscription<FileSystemEvent>>[];
  final _pending = <String>{};
  Timer? _debounce;

  Future<void> start() async {
    await stop();
    if (!FileSystemEntity.isWatchSupported) return;
    final dirs = [Directory(root)];
    await for (final entity in Directory(root).list(recursive: true)) {
      if (entity is Directory && !_hidden(entity.path)) dirs.add(entity);
    }
    for (final dir in dirs) {
      _subscriptions.add(dir.watch().listen(_onEvent, onError: (_) {}));
    }
  }

  Future<void> stop() async {
    _debounce?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }

  void _onEvent(FileSystemEvent event) {
    // A rename (our atomic write, or Syncthing's) lands at its destination.
    final path = event is FileSystemMoveEvent
        ? event.destination ?? event.path
        : event.path;
    if (!path.startsWith('$root/') || _hidden(path)) return;
    _pending.add(path.substring(root.length + 1));
    _debounce?.cancel();
    // Syncthing often writes several files in a row: wait for quiet.
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final paths = {..._pending};
      _pending.clear();
      onChange(paths);
    });
  }

  // Temp files, .obsidian, .stversions, .stfolder...
  bool _hidden(String path) =>
      path.substring(root.length).split('/').any((p) => p.startsWith('.'));
}
