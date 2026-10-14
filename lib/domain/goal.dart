import 'copy_sentinel.dart';

enum GoalKind { measurable, log }

enum GoalStatus { active, onHold, completed }

/// Something with an end. Progress is never stored; see progress.dart.
class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.kind = GoalKind.measurable,
    this.target,
    this.unit,
    this.parent,
    this.status = GoalStatus.active,
    required this.created,
    this.completed,
    this.notes = '',
    this.extra = const {},
  });

  final String id;
  final String title;
  final GoalKind kind;

  /// Measurable goals only.
  final num? target;
  final String? unit;
  final String? parent;
  final GoalStatus status;
  final DateTime created;
  final DateTime? completed;

  /// Markdown body of the goal file.
  final String notes;
  final Map<String, Object?> extra;

  Goal copyWith({
    String? title,
    GoalKind? kind,
    Object? target = keep,
    Object? unit = keep,
    Object? parent = keep,
    GoalStatus? status,
    Object? completed = keep,
    String? notes,
  }) => Goal(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    target: pick(target, this.target),
    unit: pick(unit, this.unit),
    parent: pick(parent, this.parent),
    status: status ?? this.status,
    created: created,
    completed: pick(completed, this.completed),
    notes: notes ?? this.notes,
    extra: extra,
  );
}
