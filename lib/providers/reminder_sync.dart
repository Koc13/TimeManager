import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_data.dart';
import '../domain/recurring.dart';
import 'data_providers.dart';

/// Keeps the OS's scheduled task reminders equal to what the files say.
///
/// Why reconcile instead of scheduling at each edit: tasks also change
/// outside the app's edit paths (rollover, checking off, a file edited in
/// Obsidian or synced from another device). Comparing "what should be
/// scheduled" with "what this device scheduled last time" covers all of
/// them with one rule. Reboots are covered by the notification plugin's
/// boot receiver, which re-registers scheduled alarms.
final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final sync = ReminderSync(ref);
  ref.listen(
    appDataProvider,
    (_, data) => sync.reconcile(data),
    fireImmediately: true,
  );
  return sync;
});

class ReminderSync {
  ReminderSync(this._ref);

  final Ref _ref;
  Future<void> _last = Future.value();

  /// Runs reconciliations one after another; two overlapping runs could
  /// otherwise both schedule or both cancel the same reminder.
  Future<void> reconcile(AppData data) =>
      _last = _last.then((_) => _reconcile(data)).catchError((_) {});

  Future<void> _reconcile(AppData data) async {
    final settings = _ref.read(localSettingsProvider);
    final notify = _ref.read(notificationsProvider);
    final now = _ref.read(clockProvider)();

    final scheduled = await settings?.reminders() ?? {};
    final wanted = {
      for (final MapEntry(key: id, value: r) in reminderPlan(data, now).entries)
        id: (
          key: '${r.at.toIso8601String()}|${r.title}',
          title: r.title,
          at: r.at,
        ),
    };

    for (final id in scheduled.keys) {
      if (wanted[id]?.key != scheduled[id]) {
        await notify.cancelTaskReminder(id);
      }
    }
    for (final MapEntry(key: id, value: r) in wanted.entries) {
      if (scheduled[id] != r.key) {
        await notify.scheduleTaskReminder(taskId: id, title: r.title, at: r.at);
      }
    }
    await settings?.setReminders({
      for (final MapEntry(key: id, value: r) in wanted.entries) id: r.key,
    });
  }
}
