/// The data root folder on disk, loaded fully into memory.
///
/// Only dart:io, no Flutter, so a desktop build can reuse it. There is no
/// index: a year is ~430 small files, so reading everything on start stays
/// fast for years. An index can be added later as a cache if it isn't.
library;

import 'dart:io';

import '../domain/app_data.dart';
import '../domain/goal.dart';
import '../domain/habit.dart';
import '../domain/period.dart';
import '../domain/period_doc.dart';
import '../domain/recurring.dart';
import 'codecs.dart';
import 'yaml_io.dart';

const formatVersion = 1;

class UnsupportedFormatException implements Exception {
  UnsupportedFormatException(this.found);
  final Object? found;

  @override
  String toString() =>
      'The data folder uses format_version $found; this app only reads '
      'version $formatVersion. Update the app.';
}

class DataStore {
  DataStore._(this.root);

  final String root;

  AppData _data = const AppData();
  AppData get data => _data;

  /// Syncthing conflict copies found on the last load (relative paths).
  /// They are never parsed as data.
  List<String> conflicts = [];

  /// Files that failed to parse, by relative path. They are read-only until
  /// fixed: saving over them would drop whatever couldn't be understood.
  Map<String, String> loadErrors = {};

  /// Last text read from or written to each file (relative path), so a
  /// save only touches files whose content actually changed.
  final _known = <String, String>{};

  /// Opens [root], creating `.timemanager.yaml` on first use.
  static Future<DataStore> open(String root) async {
    final store = DataStore._(root);
    await store._ensureConfig();
    await store.reload();
    return store;
  }

  Future<void> _ensureConfig() async {
    final file = File('$root/.timemanager.yaml');
    if (!await file.exists()) {
      await Directory(root).create(recursive: true);
      await _writeAtomic(file, writeYamlMap({'format_version': formatVersion}));
      return;
    }
    final version = readYamlMap(await file.readAsString())['format_version'];
    if (version != formatVersion) throw UnsupportedFormatException(version);
  }

  /// How long the last full load took; logged so it's visible when an
  /// index (optional) starts being worth it.
  Duration lastLoadTime = Duration.zero;

  /// Re-reads every file. Edits made outside the app win.
  Future<void> reload() async {
    final stopwatch = Stopwatch()..start();
    _known.clear();
    final conflicts = <String>[];
    final errors = <String, String>{};
    final goals = <String, Goal>{};
    final habits = <String, Habit>{};
    final recurring = <String, RecurringTemplate>{};
    final periods = <String, PeriodDoc>{};

    await for (final (path, text) in _markdownFiles(conflicts)) {
      final name = path.split('/').last.replaceAll(RegExp(r'\.md$'), '');
      try {
        if (path.startsWith('goals/')) {
          final goal = decodeGoal(name, text);
          goals[goal.id] = goal;
        } else if (path.startsWith('habits/')) {
          final habit = decodeHabit(name, text);
          habits[habit.id] = habit;
        } else if (path.startsWith('recurring/')) {
          final template = decodeRecurring(name, text);
          recurring[template.id] = template;
        } else if (path.startsWith('periods/')) {
          final period = Period.tryParse(name);
          if (period == null) continue; // A user's own note; not ours.
          periods[period.key] = decodePeriodDoc(period, text);
        } else {
          continue;
        }
        _known[path] = text;
      } on FormatException catch (e) {
        errors[path] = e.message;
      }
    }

    this.conflicts = conflicts;
    loadErrors = errors;
    lastLoadTime = stopwatch.elapsed;
    _data = AppData(
      goals: goals,
      habits: habits,
      recurring: recurring,
      periods: periods,
    );
  }

  /// Every data file's relative path and text. Paths are listed first and
  /// then read in parallel batches: on Android each file read goes through
  /// the shared-storage (FUSE) layer, where waiting on one file at a time
  /// is the slow part.
  Stream<(String, String)> _markdownFiles(List<String> conflicts) async* {
    final paths = <String>[];
    for (final dir in const ['goals', 'habits', 'recurring', 'periods']) {
      final directory = Directory('$root/$dir');
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.substring(root.length + 1);
        // Hidden files and folders: our temp files, Obsidian's and
        // Syncthing's own folders (.trash, .stversions).
        if (path.split('/').any((part) => part.startsWith('.'))) continue;
        if (path.contains('.sync-conflict-')) {
          conflicts.add(path);
        } else if (path.endsWith('.md')) {
          paths.add(path);
        }
      }
    }
    const batch = 32;
    for (var i = 0; i < paths.length; i += batch) {
      final chunk = paths.skip(i).take(batch).toList();
      final texts = await Future.wait(
        chunk.map((p) => File('$root/$p').readAsString()),
      );
      for (var j = 0; j < chunk.length; j++) {
        yield (chunk[j], texts[j]);
      }
    }
  }

  /// Whether any of [paths] (relative) differs from what this store last
  /// read or wrote, i.e. was changed by someone else. Lets the watcher
  /// ignore the app's own writes instead of reloading after each one.
  Future<bool> changedOnDisk(Iterable<String> paths) async {
    for (final path in paths) {
      if (path.contains('.sync-conflict-')) return true;
      if (!path.endsWith('.md')) return true; // e.g. a new folder
      final file = File('$root/$path');
      final text = await file.exists() ? await file.readAsString() : null;
      if (text != _known[path]) return true;
    }
    return false;
  }

  Future<void> savePeriods(Iterable<PeriodDoc> docs) async {
    for (final doc in docs) {
      await _save(periodPath(doc.period), encodePeriodDoc(doc));
      _data = _data.withPeriods([doc]);
    }
  }

  Future<void> saveGoal(Goal goal) async {
    await _save('goals/${goal.id}.md', encodeGoal(goal));
    _data = _data.withGoal(goal);
  }

  Future<void> saveHabit(Habit habit) async {
    await _save('habits/${habit.id}.md', encodeHabit(habit));
    _data = _data.withHabit(habit);
  }

  Future<void> deleteGoal(String id) async {
    await _delete('goals/$id.md');
    _data = _data.withoutGoal(id);
  }

  Future<void> deleteHabit(String id) async {
    await _delete('habits/$id.md');
    _data = _data.withoutHabit(id);
  }

  Future<void> saveRecurring(RecurringTemplate template) async {
    await _save('recurring/${template.id}.md', encodeRecurring(template));
    _data = _data.withRecurring(template);
  }

  Future<void> deleteRecurring(String id) async {
    await _delete('recurring/$id.md');
    _data = _data.withoutRecurring(id);
  }

  Future<void> _delete(String path) async {
    final file = File('$root/$path');
    if (await file.exists()) await file.delete();
    _known.remove(path);
    loadErrors.remove(path);
  }

  Future<void> _save(String path, String text) async {
    if (loadErrors.containsKey(path)) {
      throw FileSystemException(
        'This file could not be read, so it was not overwritten. '
        'Fix it in a text editor first',
        path,
      );
    }
    if (_known[path] == text) return;
    await _writeAtomic(File('$root/$path'), text);
    _known[path] = text;
  }
}

/// Where a period's file lives, relative to the root. Weeks are filed under
/// their ISO year, which differs from the calendar year around New Year.
String periodPath(Period period) => switch (period) {
  Day(:final date) =>
    'periods/${date.year}/${date.month.toString().padLeft(2, '0')}/${period.key}.md',
  Week(:final isoYear) => 'periods/$isoYear/${period.key}.md',
  Month(:final year) => 'periods/$year/${period.key}.md',
};

/// Writes a temp file next to [file], then renames it over [file]. A crash
/// or a Syncthing scan mid-write never sees a half-written file, because a
/// rename within one folder is atomic.
Future<void> _writeAtomic(File file, String text) async {
  await file.parent.create(recursive: true);
  final name = file.uri.pathSegments.last;
  final temp = File('${file.parent.path}/.$name.tmp');
  await temp.writeAsString(text, flush: true);
  await temp.rename(file.path);
}
