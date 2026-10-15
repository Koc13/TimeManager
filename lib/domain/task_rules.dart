/// Pure task rules: ordering, moving between lists, and rollover.
library;

import 'app_data.dart';
import 'period.dart';
import 'period_doc.dart';
import 'task.dart';

/// Open tasks in display order: priority (1 first), then deadline (none
/// last), then creation time so the order is stable.
List<Task> openTasksSorted(Iterable<Task> tasks) {
  final open = tasks.where((t) => t.isOpen).toList();
  open.sort((a, b) {
    final byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) return byPriority;
    final ad = a.deadline, bd = b.deadline;
    if (ad != bd) {
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    }
    return a.created.compareTo(b.created);
  });
  return open;
}

/// Replaces the task with the same ID, or appends it.
PeriodDoc upsertTask(PeriodDoc doc, Task task) {
  final index = doc.tasks.indexWhere((t) => t.id == task.id);
  final tasks = [...doc.tasks];
  if (index == -1) {
    tasks.add(task);
  } else {
    tasks[index] = task;
  }
  return doc.copyWith(tasks: tasks);
}

PeriodDoc removeTask(PeriodDoc doc, String id) =>
    doc.copyWith(tasks: doc.tasks.where((t) => t.id != id).toList());

/// The list a task lands in when moved from [from] to a list of [kind].
///
/// Anchored on [today] if [from] contains it, else on [from]'s first day:
/// moving this month's task to "week" puts it in the current week; moving
/// next month's task puts it in the week of that month's 1st.
Period moveTarget(Period from, PeriodKind kind, DateTime today) =>
    Period.of(kind, from.contains(today) ? today : from.start);

/// Moves every unfinished task from past *weekly and monthly* lists into the
/// current week/month, incrementing `rolledOver`. Returns only the documents
/// that changed (empty when there's nothing to do), oldest tasks first.
///
/// Daily lists don't roll over automatically: their leftovers are offered
/// for review instead (see [leftovers]), so each day starts from a choice
/// rather than from yesterday's backlog.
List<PeriodDoc> rollover(AppData data, DateTime now) {
  final changed = <PeriodDoc>[];
  for (final kind in const [PeriodKind.week, PeriodKind.month]) {
    final current = Period.of(kind, now);
    final past =
        data.periods.values
            .where(
              (doc) =>
                  doc.period.kind == kind &&
                  doc.period.compareTo(current) < 0 &&
                  doc.tasks.any((t) => t.isOpen),
            )
            .toList()
          ..sort((a, b) => a.period.compareTo(b.period));
    if (past.isEmpty) continue;

    final moved = <Task>[];
    for (final doc in past) {
      moved.addAll(
        doc.tasks
            .where((t) => t.isOpen)
            .map((t) => t.copyWith(rolledOver: t.rolledOver + 1)),
      );
      changed.add(
        doc.copyWith(tasks: doc.tasks.where((t) => !t.isOpen).toList()),
      );
    }
    final target = data.period(current);
    changed.add(target.copyWith(tasks: [...target.tasks, ...moved]));
  }
  return changed;
}

/// Unfinished tasks to offer on [target]'s page: open tasks from every
/// earlier day up to and including today. Only today's page (leftovers
/// from before) and tomorrow's page (planning tonight: what's still open
/// today) show them; other days get none. Oldest day first, then priority.
List<({Day from, Task task})> leftovers(
  AppData data,
  Day target,
  DateTime today,
) {
  final todayDay = Day(today);
  if (target != todayDay && target != todayDay.next) return const [];
  final result = <({Day from, Task task})>[];
  final days =
      data.periods.values
          .where(
            (doc) =>
                doc.period is Day &&
                doc.period.compareTo(target) < 0 &&
                doc.period.compareTo(todayDay) <= 0,
          )
          .toList()
        ..sort((a, b) => a.period.compareTo(b.period));
  for (final doc in days) {
    for (final task in openTasksSorted(doc.tasks)) {
      result.add((from: doc.period as Day, task: task));
    }
  }
  return result;
}
