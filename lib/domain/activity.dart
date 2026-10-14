import 'target_ref.dart';

/// One finished timed work block.
class Session {
  const Session({
    required this.id,
    required this.target,
    required this.start,
    required this.plannedMin,
    required this.actualMin,
    this.extra = const {},
  });

  final String id;
  final TargetRef target;
  final DateTime start;
  final int plannedMin;
  final int actualMin;
  final Map<String, Object?> extra;
}

/// A habit's value for one day: `true` for yes/no, a number for measurable.
/// The day is the file it lives in, so it has no date or ID of its own.
class HabitEntry {
  const HabitEntry({
    required this.habit,
    required this.value,
    this.extra = const {},
  });

  final String habit;
  final Object value;
  final Map<String, Object?> extra;
}

/// A dated progress entry for a goal: an amount (measurable goals) or a
/// source + quantity (log goals, e.g. "Bishop, 25 pages").
class GoalLog {
  const GoalLog({
    required this.id,
    required this.goal,
    this.amount,
    this.unit,
    this.source,
    required this.at,
    this.extra = const {},
  });

  final String id;
  final String goal;
  final num? amount;
  final String? unit;
  final String? source;
  final DateTime at;
  final Map<String, Object?> extra;
}
