import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/goal.dart';
import '../../providers/actions/goal_actions.dart';

/// "Completed: 100 LeetCode problems" with Undo, after activity pushed a
/// measurable goal over its target (auto-complete with undo).
void announceReached(
  ScaffoldMessengerState? messenger,
  WidgetRef ref,
  List<Goal> reached,
) {
  for (final goal in reached) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Completed: ${goal.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              ref.read(goalActionsProvider).setStatus(goal, GoalStatus.active),
        ),
      ),
    );
  }
}
