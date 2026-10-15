import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../domain/ids.dart';
import '../data_providers.dart';

final goalActionsProvider = Provider(GoalActions.new);

/// Goals themselves. Logging progress is in `ActivityActions`.
class GoalActions with ActionsBase {
  GoalActions(this.ref);

  @override
  final Ref ref;

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
      created: now(),
    );
    await write.saveGoal(goal);
    return goal;
  }

  Future<void> saveGoal(Goal goal) => write.saveGoal(goal);

  Future<void> deleteGoal(String id) => write.deleteGoal(id);

  /// Completed goals get today's date; any other status clears it.
  Future<void> setStatus(Goal goal, GoalStatus status) => write.saveGoal(
    goal.copyWith(
      status: status,
      completed: status == GoalStatus.completed ? now() : null,
    ),
  );
}
