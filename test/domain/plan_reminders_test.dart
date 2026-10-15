import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/plan_reminders.dart';

void main() {
  test('daily: later today if the time is still ahead, else tomorrow', () {
    const t = ReminderTime(minute: 8 * 60);
    expect(
      nextOccurrences(PlanReminder.dayPlan, t, DateTime(2026, 10, 15, 7)),
      [DateTime(2026, 10, 15, 8)],
    );
    expect(
      nextOccurrences(PlanReminder.dayPlan, t, DateTime(2026, 10, 15, 8)),
      [DateTime(2026, 10, 16, 8)],
      reason: 'strictly after now',
    );
  });

  test('weekly: the next chosen weekday', () {
    const t = ReminderTime(minute: 20 * 60, weekday: DateTime.sunday);
    // Thu 15 Oct 2026 -> Sun 18 Oct.
    expect(
      nextOccurrences(PlanReminder.weekReview, t, DateTime(2026, 10, 15, 9)),
      [DateTime(2026, 10, 18, 20)],
    );
  });

  test('monthly on the last day, three ahead, across February', () {
    const t = ReminderTime(minute: 20 * 60, monthDay: lastDay);
    expect(
      nextOccurrences(
        PlanReminder.monthReview,
        t,
        DateTime(2027, 1, 31, 21),
        count: 3,
      ),
      [
        DateTime(2027, 2, 28, 20),
        DateTime(2027, 3, 31, 20),
        DateTime(2027, 4, 30, 20),
      ],
    );
  });

  test('the time of day survives a DST change', () {
    const t = ReminderTime(minute: 8 * 60);
    // The EU spring-forward night is 28-29 March 2026.
    final next = nextOccurrences(
      PlanReminder.dayPlan,
      t,
      DateTime(2026, 3, 28, 9),
    ).single;
    expect((next.day, next.hour, next.minute), (29, 8, 0));
  });

  test('settings JSON round-trips and falls back on bad values', () {
    const t = ReminderTime(minute: 75, weekday: 3, monthDay: 0, enabled: false);
    expect(
      ReminderTime.fromJson(t.toJson(), PlanReminder.dayPlan.defaultTime),
      t,
    );
    final bad = ReminderTime.fromJson({
      'minute': 99999,
      'weekday': 9,
    }, PlanReminder.weekPlan.defaultTime);
    expect(bad, PlanReminder.weekPlan.defaultTime);
  });
}
