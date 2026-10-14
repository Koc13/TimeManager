/// Converts between domain records and frontmatter maps.
///
/// Every `encode` writes known keys in a fixed order, then the record's
/// unknown keys (`extra`) in the order they were read. Every `decode` is
/// lenient: a missing or malformed optional field falls back to a default
/// rather than rejecting a hand-edited file.
library;

import '../domain/activity.dart';
import '../domain/goal.dart';
import '../domain/habit.dart';
import '../domain/ids.dart';
import '../domain/period.dart';
import '../domain/period_doc.dart';
import '../domain/target_ref.dart';
import '../domain/task.dart';
import 'yaml_io.dart';

// ---------------------------------------------------------------- periods

String encodePeriodDoc(PeriodDoc doc) {
  final period = doc.period;
  final map = <String, Object?>{
    switch (period.kind) {
      PeriodKind.day => 'date',
      PeriodKind.week => 'week',
      PeriodKind.month => 'month',
    }: period.key,
    'tasks': doc.tasks.map(_encodeTask).toList(),
    if (period.kind == PeriodKind.day) ...{
      'sessions': doc.sessions.map(_encodeSession).toList(),
      'habit_entries': doc.habitEntries.map(_encodeHabitEntry).toList(),
      'goal_logs': doc.goalLogs.map(_encodeGoalLog).toList(),
    },
  };
  return writeMarkdown(_withExtra(map, doc.extra), doc.journal);
}

/// [period] comes from the file name, which decides where the file lives.
PeriodDoc decodePeriodDoc(Period period, String text) {
  final (:frontmatter, :body) = readMarkdown(text);
  const known = {
    'date',
    'week',
    'month',
    'tasks',
    'sessions',
    'habit_entries',
    'goal_logs',
  };
  return PeriodDoc(
    period: period,
    tasks: _list(frontmatter['tasks']).map(_decodeTask).toList(),
    sessions: _list(frontmatter['sessions']).map(_decodeSession).toList(),
    habitEntries: _list(frontmatter['habit_entries'])
        .map(_decodeHabitEntry)
        .toList(),
    goalLogs: _list(frontmatter['goal_logs']).map(_decodeGoalLog).toList(),
    journal: body,
    extra: _extra(frontmatter, known),
  );
}

Map<String, Object?> _encodeTask(Task t) => _withExtra({
  'id': t.id,
  'title': t.title,
  'priority': t.priority,
  'deadline': _time(t.deadline),
  'reminder': _time(t.reminder),
  'link': _ref(t.link),
  'recurring': t.recurring,
  'rolled_over': t.rolledOver,
  'created': _time(t.created),
  'done_at': _time(t.doneAt),
}, t.extra);

// A plain string item ("- Buy milk", typed in Obsidian) becomes a task.
Task _decodeTask(Object? item) {
  if (item is String) {
    return Task(id: newId('t'), title: item, created: DateTime.now());
  }
  final m = _map(item, 'task');
  return Task(
    // A task typed in by hand may lack an ID; it gets one on the next write.
    id: _str(m['id']) ?? newId('t'),
    title: _str(m['title']) ?? '',
    priority: switch (m['priority']) {
      final int p when p >= 1 && p <= 3 => p,
      _ => 2,
    },
    deadline: _parseTime(m['deadline']),
    reminder: _parseTime(m['reminder']),
    link: _parseRef(m['link']),
    recurring: _str(m['recurring']),
    rolledOver: m['rolled_over'] is int ? m['rolled_over'] as int : 0,
    created: _parseTime(m['created']) ?? DateTime.now(),
    doneAt: _parseTime(m['done_at']),
    extra: _extra(m, const {
      'id',
      'title',
      'priority',
      'deadline',
      'reminder',
      'link',
      'recurring',
      'rolled_over',
      'created',
      'done_at',
    }),
  );
}

Map<String, Object?> _encodeSession(Session s) => _withExtra({
  'id': s.id,
  'target': _ref(s.target),
  'start': _time(s.start),
  'planned_min': s.plannedMin,
  'actual_min': s.actualMin,
}, s.extra);

Session _decodeSession(Object? item) {
  final m = _map(item, 'session');
  final target = _parseRef(m['target']);
  final start = _parseTime(m['start']);
  if (target == null || start == null) {
    throw const FormatException('Session needs a target and a start');
  }
  return Session(
    id: _str(m['id']) ?? newId('s'),
    target: target,
    start: start,
    plannedMin: _num(m['planned_min'])?.round() ?? 0,
    actualMin: _num(m['actual_min'])?.round() ?? 0,
    extra: _extra(m, const {
      'id',
      'target',
      'start',
      'planned_min',
      'actual_min',
    }),
  );
}

Map<String, Object?> _encodeHabitEntry(HabitEntry e) =>
    _withExtra({'habit': e.habit, 'value': e.value}, e.extra);

HabitEntry _decodeHabitEntry(Object? item) {
  final m = _map(item, 'habit entry');
  final habit = _str(m['habit']);
  final value = m['value'];
  if (habit == null || (value is! bool && value is! num)) {
    throw const FormatException('Habit entry needs a habit and a value');
  }
  return HabitEntry(
    habit: habit,
    value: value!,
    extra: _extra(m, const {'habit', 'value'}),
  );
}

Map<String, Object?> _encodeGoalLog(GoalLog l) => _withExtra({
  'id': l.id,
  'goal': l.goal,
  'amount': l.amount,
  'unit': l.unit,
  'source': l.source,
  'at': _time(l.at),
}, l.extra);

GoalLog _decodeGoalLog(Object? item) {
  final m = _map(item, 'goal log');
  final goal = _str(m['goal']);
  final at = _parseTime(m['at']);
  if (goal == null || at == null) {
    throw const FormatException('Goal log needs a goal and an at time');
  }
  return GoalLog(
    id: _str(m['id']) ?? newId('l'),
    goal: goal,
    amount: _num(m['amount']),
    unit: _str(m['unit']),
    source: _str(m['source']),
    at: at,
    extra: _extra(m, const {'id', 'goal', 'amount', 'unit', 'source', 'at'}),
  );
}

// ------------------------------------------------------------ goals/habits

String encodeGoal(Goal g) => writeMarkdown(
  _withExtra({
    'id': g.id,
    'title': g.title,
    'kind': g.kind.name,
    'target': g.target,
    'unit': g.unit,
    'parent': g.parent,
    'status': _goalStatusNames[g.status],
    'created': _time(g.created),
    'completed': _time(g.completed),
  }, g.extra),
  g.notes,
);

Goal decodeGoal(String fallbackId, String text) {
  final (:frontmatter, :body) = readMarkdown(text);
  final m = frontmatter;
  return Goal(
    id: _str(m['id']) ?? fallbackId,
    title: _str(m['title']) ?? '',
    kind: m['kind'] == 'log' ? GoalKind.log : GoalKind.measurable,
    target: _num(m['target']),
    unit: _str(m['unit']),
    parent: _str(m['parent']),
    status: _goalStatusNames.entries
        .firstWhere(
          (e) => e.value == m['status'],
          orElse: () => const MapEntry(GoalStatus.active, 'active'),
        )
        .key,
    created: _parseTime(m['created']) ?? DateTime.now(),
    completed: _parseTime(m['completed']),
    notes: body,
    extra: _extra(m, const {
      'id',
      'title',
      'kind',
      'target',
      'unit',
      'parent',
      'status',
      'created',
      'completed',
    }),
  );
}

const _goalStatusNames = {
  GoalStatus.active: 'active',
  GoalStatus.onHold: 'on_hold',
  GoalStatus.completed: 'completed',
};

String encodeHabit(Habit h) => writeMarkdown(
  _withExtra({
    'id': h.id,
    'title': h.title,
    'kind': h.kind == HabitKind.yesNo ? 'yes_no' : 'measurable',
    'unit': h.unit,
    'goal': h.goal,
    'goal_amount': h.goalAmount,
    'created': _time(h.created),
  }, h.extra),
  h.notes,
);

Habit decodeHabit(String fallbackId, String text) {
  final (:frontmatter, :body) = readMarkdown(text);
  final m = frontmatter;
  return Habit(
    id: _str(m['id']) ?? fallbackId,
    title: _str(m['title']) ?? '',
    kind: m['kind'] == 'measurable' ? HabitKind.measurable : HabitKind.yesNo,
    unit: _str(m['unit']),
    goal: _str(m['goal']),
    goalAmount: _num(m['goal_amount']) ?? 1,
    created: _parseTime(m['created']) ?? DateTime.now(),
    notes: body,
    extra: _extra(m, const {
      'id',
      'title',
      'kind',
      'unit',
      'goal',
      'goal_amount',
      'created',
    }),
  );
}

// ---------------------------------------------------------------- helpers

Map<String, Object?> _withExtra(
  Map<String, Object?> known,
  Map<String, Object?> extra,
) => {
  ...known,
  for (final e in extra.entries)
    if (!known.containsKey(e.key)) e.key: e.value,
};

Map<String, Object?> _extra(Map<String, Object?> m, Set<String> known) => {
  for (final e in m.entries)
    if (!known.contains(e.key)) e.key: e.value,
};

// Entries that can't be understood make the whole file fail to load, so
// the store treats it as read-only instead of rewriting it without them.
List<Object?> _list(Object? value) => switch (value) {
  null => const [],
  List() => value,
  _ => throw const FormatException('Expected a list'),
};

Map<String, Object?> _map(Object? item, String what) =>
    item is Map<String, Object?>
    ? item
    : throw FormatException('Unreadable $what entry', '$item');

String? _str(Object? value) => switch (value) {
  null => null,
  String() => value,
  // A hand-typed title like `2026` or `true` parses as a number/bool.
  _ => '$value',
};

num? _num(Object? value) => value is num ? value : null;

Map<String, Object?>? _ref(TargetRef? ref) => switch (ref) {
  null => null,
  TargetRef(type: TargetType.custom, :final name) => {
    'type': 'custom',
    'name': name,
  },
  TargetRef(:final type, :final id) => {'type': type.name, 'id': id},
};

TargetRef? _parseRef(Object? value) {
  if (value is! Map) return null;
  final id = _str(value['id']);
  final name = _str(value['name']);
  return switch (value['type']) {
    'goal' when id != null => TargetRef.goal(id),
    'habit' when id != null => TargetRef.habit(id),
    'custom' when name != null => TargetRef.custom(name),
    _ => null,
  };
}

/// ISO 8601 with the local offset, seconds precision:
/// `2026-10-14T20:00:00+02:00`.
String? _time(DateTime? t) {
  if (t == null) return null;
  final local = t.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final h = offset.inHours.abs().toString().padLeft(2, '0');
  final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dateKey(local)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$sign$h:$m';
}

DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
