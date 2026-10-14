import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// What the app needs from notifications. An interface so tests can record
/// calls instead of talking to the platform plugin.
abstract interface class Notifications {
  /// Ongoing, non-dismissable countdown while a timer runs. Android draws
  /// the countdown itself (a chronometer), so it keeps ticking even if the
  /// app is killed.
  Future<void> showTimerRunning({required String title, required DateTime end});

  /// Replaces the running notification while paused (no countdown).
  Future<void> showTimerPaused({required String title, required String text});

  /// The alarm at the end of a work block or break. Fires even if the app
  /// is not running.
  Future<void> scheduleTimerEnd({
    required String title,
    required String body,
    required DateTime at,
  });

  /// Removes both timer notifications and the scheduled end alarm.
  Future<void> cancelTimer();

  /// Removes only the running countdown, leaving the end alarm to fire. Used
  /// when the timer ends naturally: cancelling the alarm too could race
  /// with it and silence it.
  Future<void> hideTimerRunning();

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime at,
  });

  Future<void> cancelTaskReminder(String taskId);

  /// Asks for permission to post notifications (Android 13+). Safe to call
  /// repeatedly: the OS only shows the prompt once.
  Future<void> requestPermission();
}

/// flutter_local_notifications on Android; a silent no-op elsewhere (the
/// Linux plugin has no scheduling at all, and Android is the main target).
class NotificationService implements Notifications {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _runningId = 1;
  static const _endId = 2;

  static const _running = AndroidNotificationDetails(
    'timer_running',
    'Running timer',
    channelDescription: 'Countdown while a work block or break runs',
    importance: Importance.low,
    ongoing: true,
    autoCancel: false,
    onlyAlertOnce: true,
    playSound: false,
  );

  static const _alarm = AndroidNotificationDetails(
    'timer_end',
    'Timer finished',
    channelDescription: 'When a work block or break ends',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _reminder = AndroidNotificationDetails(
    'task_reminders',
    'Task reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  bool get _enabled => Platform.isAndroid;

  /// Time zone data (zonedSchedule needs a real IANA zone) and plugin
  /// setup. Call once before anything else.
  Future<void> initialize() async {
    if (!_enabled) return;
    // `latest_all`, not `latest`: the platform can report a deprecated
    // alias (e.g. "Arctic/Longyearbyen") that the reduced set lacks.
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  @override
  Future<void> requestPermission() async {
    if (!_enabled) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> showTimerRunning({
    required String title,
    required DateTime end,
  }) async {
    if (!_enabled) return;
    final remaining = end.difference(DateTime.now());
    await _plugin.show(
      id: _runningId,
      title: title,
      body: 'Running',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _running.channelId,
          _running.channelName,
          channelDescription: _running.channelDescription,
          importance: _running.importance,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          usesChronometer: true,
          chronometerCountDown: true,
          when: end.millisecondsSinceEpoch,
          showWhen: true,
          // Disappear at the end instead of counting into negative time.
          timeoutAfter: remaining.isNegative ? 0 : remaining.inMilliseconds,
        ),
      ),
    );
  }

  @override
  Future<void> showTimerPaused({
    required String title,
    required String text,
  }) async {
    if (!_enabled) return;
    await _plugin.cancel(id: _endId);
    await _plugin.show(
      id: _runningId,
      title: title,
      body: text,
      notificationDetails: const NotificationDetails(android: _running),
    );
  }

  @override
  Future<void> scheduleTimerEnd({
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!_enabled) return;
    await _plugin.zonedSchedule(
      id: _endId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _alarm),
      // Exact: an inexact alarm can be deferred by minutes in Doze, which
      // is useless for a 25-minute timer. Allowed via USE_EXACT_ALARM in
      // the manifest (fine for a sideloaded app).
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelTimer() async {
    if (!_enabled) return;
    await _plugin.cancel(id: _runningId);
    await _plugin.cancel(id: _endId);
  }

  @override
  Future<void> hideTimerRunning() async {
    if (!_enabled) return;
    await _plugin.cancel(id: _runningId);
  }

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime at,
  }) async {
    if (!_enabled) return;
    await _plugin.zonedSchedule(
      id: taskNotificationId(taskId),
      title: title,
      body: 'Reminder',
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(android: _reminder),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_enabled) return;
    await _plugin.cancel(id: taskNotificationId(taskId));
  }
}

/// Does nothing: the default until the app installs the real service, and
/// what tests use when they don't care about notifications.
class NoNotifications implements Notifications {
  const NoNotifications();

  @override
  Future<void> showTimerRunning({
    required String title,
    required DateTime end,
  }) async {}
  @override
  Future<void> showTimerPaused({
    required String title,
    required String text,
  }) async {}
  @override
  Future<void> scheduleTimerEnd({
    required String title,
    required String body,
    required DateTime at,
  }) async {}
  @override
  Future<void> cancelTimer() async {}
  @override
  Future<void> hideTimerRunning() async {}
  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime at,
  }) async {}
  @override
  Future<void> cancelTaskReminder(String taskId) async {}
  @override
  Future<void> requestPermission() async {}
}

/// A stable notification ID per task, derived from its ID so nothing has to
/// store a mapping. Kept away from the timer's IDs 1 and 2.
int taskNotificationId(String taskId) {
  // FNV-1a: String.hashCode isn't guaranteed stable across runs.
  var hash = 0x811c9dc5;
  for (final unit in taskId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash < 16 ? hash + 16 : hash;
}
