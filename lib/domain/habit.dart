import 'copy_sentinel.dart';

enum HabitKind { yesNo, measurable }

/// Something ongoing with no end, logged at most once per day.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.kind = HabitKind.yesNo,
    this.unit,
    this.goal,
    this.goalAmount = 1,
    required this.created,
    this.notes = '',
    this.extra = const {},
  });

  final String id;
  final String title;
  final HabitKind kind;
  final String? unit;

  /// Linked goal: each entry also counts as progress toward it.
  final String? goal;

  /// What one yes/no check adds to the linked goal. Measurable entries add
  /// their own value instead.
  final num goalAmount;
  final DateTime created;
  final String notes;
  final Map<String, Object?> extra;

  Habit copyWith({
    String? title,
    HabitKind? kind,
    Object? unit = keep,
    Object? goal = keep,
    num? goalAmount,
    String? notes,
  }) => Habit(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    unit: pick(unit, this.unit),
    goal: pick(goal, this.goal),
    goalAmount: goalAmount ?? this.goalAmount,
    created: created,
    notes: notes ?? this.notes,
    extra: extra,
  );
}
