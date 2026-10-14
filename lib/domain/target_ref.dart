/// A reference to a goal, a habit, or (for sessions only) a custom name.
/// Stored as `{type: goal, id: g_...}` or `{type: custom, name: "..."}`.
enum TargetType { goal, habit, custom }

class TargetRef {
  const TargetRef.goal(String this.id) : type = TargetType.goal, name = null;
  const TargetRef.habit(String this.id) : type = TargetType.habit, name = null;
  const TargetRef.custom(String this.name)
    : type = TargetType.custom,
      id = null;

  final TargetType type;
  final String? id;
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is TargetRef &&
      other.type == type &&
      other.id == id &&
      other.name == name;

  @override
  int get hashCode => Object.hash(type, id, name);
}
