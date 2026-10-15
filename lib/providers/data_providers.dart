import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activity.dart';
import '../domain/app_data.dart';
import '../domain/goal.dart';
import '../domain/habit.dart';
import '../domain/ids.dart';
import '../domain/period.dart';
import '../domain/period_doc.dart';
import '../domain/task.dart';
import '../domain/progress.dart' as progress;
import '../domain/recurring.dart';
import '../domain/recurring.dart' as recurring;
import '../domain/task_rules.dart' as rules;
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

  /// Reloads only if [paths] were changed by someone else (the folder
  /// watcher also sees the app's own writes). Returns whether it reloaded.
  Future<bool> reloadIfChanged(Set<String> paths) async {
    if (!await _store.changedOnDisk(paths)) return false;
    await reload();
    return true;
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
    DateTime? deadline,
    DateTime? reminder,
  }) {
    final task = Task(
      id: newId('t'),
      title: title,
      priority: priority,
      deadline: deadline,
      reminder: reminder,
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
  Future<void> moveTask(Period from, Task task, PeriodKind kind) =>
      moveTaskTo(from, task, rules.moveTarget(from, kind, _now()));

  /// Moves [task] from [from] to [to]. [deferred] counts it as carried
  /// forward (the ↻ badge), as postponing and keeping a leftover do.
  Future<void> moveTaskTo(
    Period from,
    Task task,
    Period to, {
    bool deferred = false,
  }) {
    if (to == from) return Future.value();
    final moved = deferred
        ? task.copyWith(rolledOver: task.rolledOver + 1)
        : task;
    return _savePeriods([
      rules.removeTask(state.period(from), task.id),
      rules.upsertTask(state.period(to), moved),
    ]);
  }

  /// To the next day (or week, or month for those lists).
  Future<void> postpone(Period from, Task task) =>
      moveTaskTo(from, task, from.next, deferred: true);

  /// Carries leftovers into [to] (one write per file touched).
  Future<void> keepLeftovers(List<({Day from, Task task})> items, Day to) {
    final docs = <String, PeriodDoc>{};
    PeriodDoc doc(Period p) => docs[p.key] ?? state.period(p);
    for (final (:from, :task) in items) {
      docs[from.key] = rules.removeTask(doc(from), task.id);
      docs[to.key] = rules.upsertTask(
        doc(to),
        task.copyWith(rolledOver: task.rolledOver + 1),
      );
    }
    return _savePeriods(docs.values);
  }

  /// Marks leftovers as dropped where they are; [undo] clears it again.
  Future<void> dropLeftovers(
    List<({Day from, Task task})> items, {
    bool undo = false,
  }) {
    final docs = <String, PeriodDoc>{};
    for (final (:from, :task) in items) {
      final doc = docs[from.key] ?? state.period(from);
      docs[from.key] = rules.upsertTask(
        doc,
        task.copyWith(droppedAt: undo ? null : _now()),
      );
    }
    return _savePeriods(docs.values);
  }

  Future<void> setJournal(Period period, String text) {
    final doc = state.period(period);
    if (doc.journal == text) return Future.value();
    return _savePeriods([doc.copyWith(journal: text)]);
  }

  // ------------------------------------------------------------- goals

  Future<Goal> createGoal({
    required String title,
    required GoalKind kind,
    num? target,
    String? unit,
    String? parent,
  }) async {
    final goal = Goal(
      id: newId('g'),
      title: title,
      kind: kind,
      target: target,
      unit: unit,
      parent: parent,
      created: _now(),
    );
    await saveGoal(goal);
    return goal;
  }

  Future<void> saveGoal(Goal goal) async {
    try {
      await _store.saveGoal(goal);
    } finally {
      state = _store.data;
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _store.deleteGoal(id);
    } finally {
      state = _store.data;
    }
  }

  /// Completed goals get today's date; any other status clears it.
  Future<void> setGoalStatus(Goal goal, GoalStatus status) => saveGoal(
    goal.copyWith(
      status: status,
      completed: status == GoalStatus.completed ? _now() : null,
    ),
  );

  /// Records a log in today's file. Returns goals this pushed past their
  /// target, which are completed automatically (the UI offers Undo).
  Future<List<Goal>> addGoalLog({
    required String goal,
    num? amount,
    String? unit,
    String? source,
  }) {
    final log = GoalLog(
      id: newId('l'),
      goal: goal,
      amount: amount,
      unit: unit,
      source: source,
      at: _now(),
    );
    final day = state.period(Day(_now()));
    return _recordActivity([
      day.copyWith(goalLogs: [...day.goalLogs, log]),
    ]);
  }

  Future<void> deleteGoalLog(Day day, String id) {
    final doc = state.period(day);
    return _savePeriods([
      doc.copyWith(goalLogs: doc.goalLogs.where((l) => l.id != id).toList()),
    ]);
  }

  // ------------------------------------------------------------ habits

  Future<void> saveHabit(Habit habit) async {
    try {
      await _store.saveHabit(habit);
    } finally {
      state = _store.data;
    }
  }

  Future<void> createHabit({
    required String title,
    required HabitKind kind,
    String? unit,
    String? goal,
    num goalAmount = 1,
  }) => saveHabit(
    Habit(
      id: newId('h'),
      title: title,
      kind: kind,
      unit: unit,
      goal: goal,
      goalAmount: goalAmount,
      created: _now(),
    ),
  );

  Future<void> deleteHabit(String id) async {
    try {
      await _store.deleteHabit(id);
    } finally {
      state = _store.data;
    }
  }

  /// Sets a habit's entry for [day]: `true` or a number records it, `null`
  /// removes it. One entry per habit per day, so this replaces any other.
  /// Returns goals this pushed past their target (see [_recordActivity]).
  Future<List<Goal>> setHabitEntry(Day day, String habit, Object? value) {
    final doc = state.period(day);
    final entries = [...doc.habitEntries];
    final index = entries.indexWhere((e) => e.habit == habit);
    if (value == null) {
      if (index == -1) return Future.value(const []);
      entries.removeAt(index);
    } else {
      final entry = HabitEntry(
        habit: habit,
        value: value,
        extra: index == -1 ? const {} : entries[index].extra,
      );
      if (index == -1) {
        entries.add(entry);
      } else {
        entries[index] = entry;
      }
    }
    return _recordActivity([doc.copyWith(habitEntries: entries)]);
  }

  // ---------------------------------------------------------- sessions

  /// Writes [session] into the day it started, replacing one with the same
  /// ID (finishing a block twice must not log it twice).
  Future<List<Goal>> recordSession(Session session) {
    final doc = state.period(Day(session.start));
    return _recordActivity([
      doc.copyWith(
        sessions: [...doc.sessions.where((s) => s.id != session.id), session],
      ),
    ]);
  }

  /// Saves activity (logs, habit entries, sessions) and auto-completes
  /// measurable goals that it pushed over their target.
  Future<List<Goal>> _recordActivity(List<PeriodDoc> docs) async {
    final before = state;
    await _savePeriods(docs);
    final reached = progress.newlyReachedTargets(before, state);
    for (final goal in reached) {
      await setGoalStatus(goal, GoalStatus.completed);
    }
    return reached;
  }

  // --------------------------------------------------------- recurring

  /// Saves a new template and creates today's instance if it is due.
  Future<void> createRecurring({
    required String title,
    required int priority,
    required RepeatRule rule,
    int? reminderMinute,
  }) async {
    final template = RecurringTemplate(
      id: newId('r'),
      title: title,
      priority: priority,
      rule: rule,
      reminderMinute: reminderMinute,
      created: _now(),
    );
    try {
      await _store.saveRecurring(template);
    } finally {
      state = _store.data;
    }
    await generateRecurring();
  }

  /// Stops a series. Instances already created stay where they are.
  Future<void> deleteRecurring(String id) async {
    try {
      await _store.deleteRecurring(id);
    } finally {
      state = _store.data;
    }
  }

  Future<void> generateRecurring() async {
    final (:docs, :templates) = recurring.generateRecurring(state, _now());
    try {
      // Instances first: if a write fails, the template isn't marked as
      // generated and the next app open retries.
      await _store.savePeriods(docs);
      for (final t in templates) {
        await _store.saveRecurring(t);
      }
    } finally {
      state = _store.data;
    }
  }

  /// Start-of-day bookkeeping: roll unfinished tasks forward, then create
  /// recurring instances (in that order, so a rolled-over open instance
  /// stops a duplicate from being created).
  Future<void> startDay() async {
    final changed = rules.rollover(state, _now());
    if (changed.isNotEmpty) await _savePeriods(changed);
    await generateRecurring();
  }
}
