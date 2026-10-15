import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_data.dart';
import '../domain/goal.dart';
import '../domain/habit.dart';
import '../domain/period.dart';
import '../domain/period_doc.dart';
import '../domain/recurring.dart';
import '../notifications/notification_service.dart';
import '../storage/data_store.dart';
import '../storage/local_settings.dart';

/// The opened data folder. Always overridden in the ProviderScope that
/// app.dart creates once a folder is open, so everything below it can
/// assume one exists.
final dataStoreProvider = Provider<DataStore>(
  (ref) => throw StateError('dataStoreProvider must be overridden'),
);

/// Opens another data folder and restarts the app on it. Provided by
/// app.dart, which owns the open store.
final switchDataFolderProvider = Provider<Future<void> Function(String path)>(
  (ref) =>
      (_) async => throw UnsupportedError('No app to switch folders in'),
);

/// The folder picker, swappable in tests (the real one is a platform dialog).
final pickDataFolderProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => null,
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

/// Device-local settings; null in tests that don't need persistence.
final localSettingsProvider = Provider<LocalSettings?>((ref) => null);

final notificationsProvider = Provider<Notifications>(
  (ref) => const NoNotifications(),
);

/// Goals that just got auto-completed by something without its own UI at
/// hand (the timer finishing in the background). The shell shows them.
final reachedGoalsProvider = NotifierProvider<ReachedGoals, List<Goal>>(
  ReachedGoals.new,
);

class ReachedGoals extends Notifier<List<Goal>> {
  @override
  List<Goal> build() => const [];

  void announce(List<Goal> goals) {
    if (goals.isNotEmpty) state = goals;
  }
}

/// Problems found in the data folder on the last load: Syncthing conflict
/// copies, and files that couldn't be read (they are read-only until fixed).
/// Recomputed whenever the data changes, which includes every reload.
final storeIssuesProvider =
    Provider<({List<String> conflicts, Map<String, String> unreadable})>((ref) {
      ref.watch(appDataProvider);
      final store = ref.read(dataStoreProvider);
      return (conflicts: store.conflicts, unreadable: store.loadErrors);
    });

/// The in-memory data set: one immutable snapshot of everything.
///
/// Why one snapshot rather than one state per feature: the derived views
/// cross features (goal progress reads habit entries and timer sessions),
/// so separate states would have to be kept in sync. Instead this notifier
/// owns the data and the *writes*, and feature code lives in action classes
/// (`providers/actions/`) that call these writes.
final appDataProvider = NotifierProvider<AppDataController, AppData>(
  AppDataController.new,
);

class AppDataController extends Notifier<AppData> {
  DataStore get _store => ref.read(dataStoreProvider);

  @override
  AppData build() => ref.watch(dataStoreProvider).data;

  Future<void> reload() => _write((store) => store.reload());

  /// Reloads only if [paths] were changed by someone else (the folder
  /// watcher also sees the app's own writes). Returns whether it reloaded.
  Future<bool> reloadIfChanged(Set<String> paths) async {
    if (!await _store.changedOnDisk(paths)) return false;
    await reload();
    return true;
  }

  // The only ways data changes: write the files, then publish. Every one
  // publishes even on failure, since part of a batch may have been written.

  Future<void> savePeriods(Iterable<PeriodDoc> docs) =>
      _write((store) => store.savePeriods(docs));

  Future<void> saveGoal(Goal goal) => _write((store) => store.saveGoal(goal));

  Future<void> deleteGoal(String id) => _write((store) => store.deleteGoal(id));

  Future<void> saveHabit(Habit habit) =>
      _write((store) => store.saveHabit(habit));

  Future<void> deleteHabit(String id) =>
      _write((store) => store.deleteHabit(id));

  Future<void> saveRecurring(Iterable<RecurringTemplate> templates) =>
      _write((store) async {
        for (final t in templates) {
          await store.saveRecurring(t);
        }
      });

  Future<void> deleteRecurring(String id) =>
      _write((store) => store.deleteRecurring(id));

  Future<void> _write(Future<void> Function(DataStore store) write) async {
    try {
      await write(_store);
    } finally {
      state = _store.data;
    }
  }
}

/// Shared by the action classes: the current data and "now".
mixin ActionsBase {
  Ref get ref;
  AppData get data => ref.read(appDataProvider);
  AppDataController get write => ref.read(appDataProvider.notifier);
  DateTime now() => ref.read(clockProvider)();
  PeriodDoc doc(Period period) => data.period(period);
}
