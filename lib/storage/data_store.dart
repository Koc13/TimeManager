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

  /// Re-reads every file. Edits made outside the app win.
  Future<void> reload() async {
    _known.clear();
    final conflicts = <String>[];
    final errors = <String, String>{};
    final goals = <String, Goal>{};
    final habits = <String, Habit>{};
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
    _data = AppData(goals: goals, habits: habits, periods: periods);
  }

  Stream<(String, String)> _markdownFiles(List<String> conflicts) async* {
    for (final dir in const ['goals', 'habits', 'periods']) {
      final directory = Directory('$root/$dir');
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.substring(root.length + 1);
        final name = path.split('/').last;
        if (name.contains('.sync-conflict-')) {
          conflicts.add(path);
        } else if (name.endsWith('.md') && !name.startsWith('.')) {
          yield (path, await entity.readAsString());
        }
      }
    }
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
  DayPeriod(:final date) =>
    'periods/${date.year}/${date.month.toString().padLeft(2, '0')}/${period.key}.md',
  WeekPeriod(:final isoYear) => 'periods/$isoYear/${period.key}.md',
  MonthPeriod(:final year) => 'periods/$year/${period.key}.md',
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
