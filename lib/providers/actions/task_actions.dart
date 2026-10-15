import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ids.dart';
import '../../domain/period.dart';
import '../../domain/period_doc.dart';
import '../../domain/recurring.dart';
import '../../domain/task.dart';
import '../../domain/task_rules.dart' as rules;
import '../data_providers.dart';

final taskActionsProvider = Provider(TaskActions.new);

/// Tasks in their period lists, the journal, start-of-day bookkeeping and
/// recurring series.
class TaskActions with ActionsBase {
  TaskActions(this.ref);

  @override
  final Ref ref;

  Future<void> addTask(
    Period period, {
    required String title,
    int priority = 2,
    DateTime? deadline,
    DateTime? reminder,
  }) => saveTask(
    period,
    Task(
      id: newId('t'),
      title: title,
      priority: priority,
      deadline: deadline,
      reminder: reminder,
      created: now(),
    ),
  );

  Future<void> saveTask(Period period, Task task) =>
      write.savePeriods([rules.upsertTask(doc(period), task)]);

  Future<void> deleteTask(Period period, String id) =>
      write.savePeriods([rules.removeTask(doc(period), id)]);

  Future<void> setDone(Period period, Task task, bool done) =>
      saveTask(period, task.copyWith(doneAt: done ? now() : null));

  /// Moves [task] out of [from] into the matching list of [kind].
  Future<void> moveTask(Period from, Task task, PeriodKind kind) =>
      moveTaskTo(from, task, rules.moveTarget(from, kind, now()));

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
    return write.savePeriods([
      rules.removeTask(doc(from), task.id),
      rules.upsertTask(doc(to), moved),
    ]);
  }

  /// To the next day (or week, or month for those lists).
  Future<void> postpone(Period from, Task task) =>
      moveTaskTo(from, task, from.next, deferred: true);

  /// Carries leftovers into [to] (one write per file touched).
  Future<void> keepLeftovers(List<({Day from, Task task})> items, Day to) {
    final docs = <String, PeriodDoc>{};
    PeriodDoc current(Period p) => docs[p.key] ?? doc(p);
    for (final (:from, :task) in items) {
      docs[from.key] = rules.removeTask(current(from), task.id);
      docs[to.key] = rules.upsertTask(
        current(to),
        task.copyWith(rolledOver: task.rolledOver + 1),
      );
    }
    return write.savePeriods(docs.values);
  }

  /// Marks leftovers as dropped where they are; [undo] clears it again.
  Future<void> dropLeftovers(
    List<({Day from, Task task})> items, {
    bool undo = false,
  }) {
    final docs = <String, PeriodDoc>{};
    for (final (:from, :task) in items) {
      docs[from.key] = rules.upsertTask(
        docs[from.key] ?? doc(from),
        task.copyWith(droppedAt: undo ? null : now()),
      );
    }
    return write.savePeriods(docs.values);
  }

  Future<void> setJournal(Period period, String text) {
    final current = doc(period);
    if (current.journal == text) return Future.value();
    return write.savePeriods([current.copyWith(journal: text)]);
  }

  /// Start-of-day bookkeeping: roll weekly/monthly lists forward, then
  /// create recurring instances (in that order, so a rolled-over open
  /// instance stops a duplicate from being created).
  Future<void> startDay() async {
    final changed = rules.rollover(data, now());
    if (changed.isNotEmpty) await write.savePeriods(changed);
    await generateRecurring();
  }

  // ---------------------------------------------------------- recurring

  /// Saves a new template and creates today's instance if it is due.
  Future<void> createRecurring({
    required String title,
    required int priority,
    required RepeatRule rule,
    int? reminderMinute,
  }) async {
    await write.saveRecurring([
      RecurringTemplate(
        id: newId('r'),
        title: title,
        priority: priority,
        rule: rule,
        reminderMinute: reminderMinute,
        created: now(),
      ),
    ]);
    await generateRecurring();
  }

  /// Stops a series. Instances already created stay where they are.
  Future<void> deleteRecurring(String id) => write.deleteRecurring(id);

  Future<void> generateRecurring() async {
    final (:docs, :templates) = generateRecurringTasks(data, now());
    // Instances first: if that write fails, the templates aren't marked as
    // generated and the next app open retries.
    await write.savePeriods(docs);
    await write.saveRecurring(templates);
  }
}
