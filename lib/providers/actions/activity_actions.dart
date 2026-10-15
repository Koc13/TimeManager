import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity.dart';
import '../../domain/goal.dart';
import '../../domain/ids.dart';
import '../../domain/period.dart';
import '../../domain/period_doc.dart';
import '../../domain/progress.dart';
import '../data_providers.dart';
import 'goal_actions.dart';

final activityActionsProvider = Provider(ActivityActions.new);

/// Recorded facts that count toward goals: goal logs, habit entries and
/// timer sessions. Each returns the goals it pushed past their target,
/// which are completed automatically (the UI offers Undo).
class ActivityActions with ActionsBase {
  ActivityActions(this.ref);

  @override
  final Ref ref;

  /// Records a log in today's file.
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
      at: now(),
    );
    final day = doc(Day(now()));
    return _record([
      day.copyWith(goalLogs: [...day.goalLogs, log]),
    ]);
  }

  Future<void> deleteGoalLog(Day day, String id) {
    final current = doc(day);
    return write.savePeriods([
      current.copyWith(
        goalLogs: current.goalLogs.where((l) => l.id != id).toList(),
      ),
    ]);
  }

  /// Sets a habit's entry for [day]: `true` or a number records it, `null`
  /// removes it. One entry per habit per day, so this replaces any other.
  Future<List<Goal>> setHabitEntry(Day day, String habit, Object? value) {
    final current = doc(day);
    final entries = [...current.habitEntries];
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
    return _record([current.copyWith(habitEntries: entries)]);
  }

  /// Writes [session] into the day it started, replacing one with the same
  /// ID (finishing a block twice must not log it twice).
  Future<List<Goal>> recordSession(Session session) {
    final current = doc(Day(session.start));
    return _record([
      current.copyWith(
        sessions: [
          ...current.sessions.where((s) => s.id != session.id),
          session,
        ],
      ),
    ]);
  }

  Future<List<Goal>> _record(List<PeriodDoc> docs) async {
    final before = data;
    await write.savePeriods(docs);
    final reached = newlyReachedTargets(before, data);
    final goals = ref.read(goalActionsProvider);
    for (final goal in reached) {
      await goals.setStatus(goal, GoalStatus.completed);
    }
    return reached;
  }
}
