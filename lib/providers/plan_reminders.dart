import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/period.dart';
import '../domain/plan_reminders.dart';
import '../notifications/notification_service.dart';
import 'data_providers.dart';

/// The stored settings JSON, read before the app starts (app.dart).
final restoredPlanRemindersProvider = Provider<Object?>((ref) => null);

typedef PlanReminderSettings = Map<PlanReminder, ReminderTime>;

final planRemindersProvider =
    NotifierProvider<PlanRemindersController, PlanReminderSettings>(
      PlanRemindersController.new,
    );

/// The six plan/review reminders: settings (device-local, in
/// local_settings.json) plus keeping the OS schedule in line with them.
class PlanRemindersController extends Notifier<PlanReminderSettings> {
  @override
  PlanReminderSettings build() {
    final json = ref.read(restoredPlanRemindersProvider);
    final map = json is Map ? json : const {};
    return {
      for (final r in PlanReminder.values)
        r: ReminderTime.fromJson(map[r.name], r.defaultTime),
    };
  }

  Future<void> set(PlanReminder reminder, ReminderTime time) async {
    state = {...state, reminder: time};
    await ref.read(localSettingsProvider)?.setPlanReminders({
      for (final MapEntry(:key, :value) in state.entries)
        key.name: value.toJson(),
    });
    await reschedule();
  }

  /// Replaces every scheduled plan reminder. Called on start, at midnight,
  /// on resume and after a change: cheap (a dozen calls), and it tops up
  /// the monthly ones, which are scheduled a few occurrences ahead because
  /// Android's repeating alarms can't say "last day of the month".
  Future<void> reschedule() async {
    final notify = ref.read(notificationsProvider);
    final now = ref.read(clockProvider)();
    if (state.values.any((t) => t.enabled)) await notify.requestPermission();

    for (final (index, reminder) in PlanReminder.values.indexed) {
      for (var k = 0; k < 3; k++) {
        await notify.cancel(planNotificationId(index, k));
      }
      final time = state[reminder]!;
      if (!time.enabled) continue;

      final monthly = reminder.kind == PeriodKind.month;
      final times = nextOccurrences(
        reminder,
        time,
        now,
        count: monthly ? 3 : 1,
      );
      for (final (k, at) in times.indexed) {
        await notify.schedule(
          id: planNotificationId(index, k),
          channel: ReminderChannel.plans,
          title: reminder.title,
          body: reminder.body,
          at: at,
          payload: 'open:${reminder.kind.name}',
          repeat: switch (reminder.kind) {
            PeriodKind.day => Repeat.daily,
            PeriodKind.week => Repeat.weekly,
            PeriodKind.month => Repeat.none,
          },
        );
      }
    }
  }
}

/// A pending request to show the ToDo list of a kind, from tapping a plan
/// reminder. The counter makes two taps for the same kind two events; the
/// pager clears it once handled.
final todoFocusProvider = NotifierProvider<TodoFocus, (PeriodKind, int)?>(
  TodoFocus.new,
);

class TodoFocus extends Notifier<(PeriodKind, int)?> {
  @override
  (PeriodKind, int)? build() => null;

  void show(PeriodKind kind) => state = (kind, (state?.$2 ?? 0) + 1);

  /// Called once the ToDo has shown the requested list.
  void clear() => state = null;
}
