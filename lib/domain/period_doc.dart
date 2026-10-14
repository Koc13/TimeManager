import 'activity.dart';
import 'period.dart';
import 'task.dart';

/// Everything recorded for one period: one file on disk.
///
/// Week and month documents only use [tasks] and [journal]; the activity
/// lists stay empty for them.
class PeriodDoc {
  const PeriodDoc({
    required this.period,
    this.tasks = const [],
    this.sessions = const [],
    this.habitEntries = const [],
    this.goalLogs = const [],
    this.journal = '',
    this.extra = const {},
  });

  PeriodDoc.empty(this.period)
    : tasks = const [],
      sessions = const [],
      habitEntries = const [],
      goalLogs = const [],
      journal = '',
      extra = const {};

  final Period period;
  final List<Task> tasks;
  final List<Session> sessions;
  final List<HabitEntry> habitEntries;
  final List<GoalLog> goalLogs;

  /// Markdown body: nightly journal (day) or review notes (week/month).
  final String journal;
  final Map<String, Object?> extra;

  PeriodDoc copyWith({
    List<Task>? tasks,
    List<Session>? sessions,
    List<HabitEntry>? habitEntries,
    List<GoalLog>? goalLogs,
    String? journal,
  }) => PeriodDoc(
    period: period,
    tasks: tasks ?? this.tasks,
    sessions: sessions ?? this.sessions,
    habitEntries: habitEntries ?? this.habitEntries,
    goalLogs: goalLogs ?? this.goalLogs,
    journal: journal ?? this.journal,
    extra: extra,
  );
}
