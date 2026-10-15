import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/habit.dart';
import '../../domain/ids.dart';
import '../data_providers.dart';

final habitActionsProvider = Provider(HabitActions.new);

/// Habits themselves. Entries are in `ActivityActions`.
class HabitActions with ActionsBase {
  HabitActions(this.ref);

  @override
  final Ref ref;

  Future<void> createHabit({
    required String title,
    required HabitKind kind,
    String? unit,
    String? goal,
    num goalAmount = 1,
  }) => write.saveHabit(
    Habit(
      id: newId('h'),
      title: title,
      kind: kind,
      unit: unit,
      goal: goal,
      goalAmount: goalAmount,
      created: now(),
    ),
  );

  Future<void> saveHabit(Habit habit) => write.saveHabit(habit);

  Future<void> deleteHabit(String id) => write.deleteHabit(id);
}
