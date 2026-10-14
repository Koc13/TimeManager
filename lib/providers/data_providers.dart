import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_data.dart';
import '../domain/ids.dart';
import '../domain/period.dart';
import '../domain/period_doc.dart';
import '../domain/task.dart';
import '../domain/task_rules.dart' as rules;
import '../storage/data_store.dart';

/// The opened data folder. Always overridden in the ProviderScope that
/// app.dart creates once a folder is open, so everything below it can
/// assume one exists.
final dataStoreProvider = Provider<DataStore>(
  (ref) => throw StateError('dataStoreProvider must be overridden'),
);

/// "Now", injectable so tests can pin the date.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Local midnight of today. The shell calls [TodayNotifier.refresh] at
/// midnight and on resume; screens showing "the current period" listen.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => midnight(ref.read(clockProvider)());

  void refresh() {
    final today = midnight(ref.read(clockProvider)());
    if (today != state) state = today;
  }
}

/// The in-memory data set. Every change goes through this controller: it
/// writes the files first, then publishes the store's new state, so the UI
/// never shows something that isn't on disk.
final appDataProvider = NotifierProvider<AppDataController, AppData>(
  AppDataController.new,
);

class AppDataController extends Notifier<AppData> {
  DataStore get _store => ref.read(dataStoreProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  AppData build() => ref.watch(dataStoreProvider).data;

  Future<void> reload() async {
    await _store.reload();
    state = _store.data;
  }

  Future<void> _savePeriods(Iterable<PeriodDoc> docs) async {
    try {
      await _store.savePeriods(docs);
    } finally {
      // Publish even on failure: earlier docs in the batch may be written.
      state = _store.data;
    }
  }

  Future<void> addTask(
    Period period, {
    required String title,
    int priority = 2,
  }) {
    final task = Task(
      id: newId('t'),
      title: title,
      priority: priority,
      created: _now(),
    );
    return _savePeriods([rules.upsertTask(state.period(period), task)]);
  }

  Future<void> saveTask(Period period, Task task) =>
      _savePeriods([rules.upsertTask(state.period(period), task)]);

  Future<void> deleteTask(Period period, String id) =>
      _savePeriods([rules.removeTask(state.period(period), id)]);

  Future<void> setDone(Period period, Task task, bool done) =>
      saveTask(period, task.copyWith(doneAt: done ? _now() : null));

  /// Moves [task] out of [from] into the matching list of [kind].
  Future<void> moveTask(Period from, Task task, PeriodKind kind) {
    final to = rules.moveTarget(from, kind, _now());
    if (to == from) return Future.value();
    return _savePeriods([
      rules.removeTask(state.period(from), task.id),
      rules.upsertTask(state.period(to), task),
    ]);
  }

  /// Moves unfinished tasks of past periods into the current ones.
  Future<void> rollover() async {
    final changed = rules.rollover(state, _now());
    if (changed.isNotEmpty) await _savePeriods(changed);
  }
}
