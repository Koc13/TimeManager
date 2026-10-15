import 'copy_sentinel.dart';
import 'target_ref.dart';

/// A to-do item living in exactly one period list (day, week or month).
class Task {
  const Task({
    required this.id,
    required this.title,
    this.priority = 2,
    this.deadline,
    this.reminder,
    this.link,
    this.recurring,
    this.rolledOver = 0,
    required this.created,
    this.doneAt,
    this.droppedAt,
    this.extra = const {},
  });

  final String id;
  final String title;

  /// 1 = high, 2 = medium, 3 = low. Lists sort ascending.
  final int priority;
  final DateTime? deadline;
  final DateTime? reminder;

  /// Goal or habit this task relates to. Informational only.
  final TargetRef? link;

  /// ID of the recurring template that generated this instance.
  final String? recurring;

  /// How many times rollover has moved this task forward.
  final int rolledOver;
  final DateTime created;
  final DateTime? doneAt;

  /// When the user chose not to carry this unfinished task forward. It
  /// stays in its day's file as history, but no longer counts as open.
  final DateTime? droppedAt;

  /// Frontmatter keys this app doesn't know, kept so they survive a write.
  final Map<String, Object?> extra;

  bool get isDone => doneAt != null;

  /// Still to do: neither done nor dropped.
  bool get isOpen => doneAt == null && droppedAt == null;

  Task copyWith({
    String? title,
    int? priority,
    Object? deadline = keep,
    Object? reminder = keep,
    Object? link = keep,
    int? rolledOver,
    Object? doneAt = keep,
    Object? droppedAt = keep,
  }) => Task(
    id: id,
    title: title ?? this.title,
    priority: priority ?? this.priority,
    deadline: pick(deadline, this.deadline),
    reminder: pick(reminder, this.reminder),
    link: pick(link, this.link),
    recurring: recurring,
    rolledOver: rolledOver ?? this.rolledOver,
    created: created,
    doneAt: pick(doneAt, this.doneAt),
    droppedAt: pick(droppedAt, this.droppedAt),
    extra: extra,
  );
}
