import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around flutter_local_notifications - owns plugin init,
/// permission request, and (later) scheduling. Deliberately no
/// habit/task/goal-specific logic here - that's a caller's job (see
/// habit_reminder_scheduler.dart), the same "generic infra vs. feature
/// logic that composes it" split every repository in this app already
/// draws.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _habitReminderChannelId = 'habit_reminders';
  static const _habitReminderChannelName = 'Habit reminders';

  /// True only on Android - flutter_local_notifications_linux has no
  /// zonedSchedule() implementation at all ("Scheduled/pending
  /// notifications is currently not supported due to the lack of a
  /// scheduler API" - package README), and it's not just missing, it's
  /// documented as a deliberate `UnimplementedError` on Linux. Real Linux
  /// background scheduling would need entirely separate OS-level
  /// infrastructure (e.g. systemd user timers) outside this package -
  /// out of scope for this first slice, so reminders are Android-only for
  /// now. UI that offers setting a reminder should check this and hide
  /// itself where it's false, rather than offering something that would
  /// silently never fire.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Sets up timezone data (zonedSchedule needs an explicit IANA zone, not
  /// just "local") and the plugin itself. Call once, before any
  /// scheduling/showing.
  Future<void> initialize() async {
    // `latest_all` (not `latest`) deliberately - the platform can report a
    // deprecated IANA alias (e.g. "Arctic/Longyearbyen"), which `latest`'s
    // reduced canonical-only dataset doesn't contain, throwing
    // LocationNotFoundException and crashing startup before runApp().
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        linux: linuxSettings,
      ),
    );
  }

  /// Android-only (a no-op on every other platform, including Linux, which
  /// has no comparable runtime permission) - required on API 33+ before a
  /// notification will actually display. Safe to call unconditionally.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Schedules (or reschedules - flutter_local_notifications overwrites an
  /// existing alarm sharing the same id) a daily reminder for [habitId] at
  /// [minuteOfDay] (0-1439, local time), recurring forever until cancelled.
  /// Deliberately inexact (AndroidScheduleMode.inexactAllowWhileIdle, not
  /// an exact alarm) - a personal daily habit reminder doesn't need
  /// to-the-second precision, and this sidesteps the
  /// SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM special-app-access permission
  /// dance entirely. "AllowWhileIdle" still ensures it fires even during
  /// Doze, just not necessarily at the exact second.
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitTitle,
    required int minuteOfDay,
  }) {
    if (!isSupported) return Future.value();
    return _plugin.zonedSchedule(
      id: habitNotificationId(habitId),
      title: habitTitle,
      body: "Time for your habit - don't forget to log it.",
      scheduledDate: _nextOccurrence(minuteOfDay),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _habitReminderChannelId,
          _habitReminderChannelName,
        ),
        linux: LinuxNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Recurs daily at the same time - only the time-of-day components of
      // scheduledDate are matched going forward, not the specific date.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelHabitReminder(String habitId) {
    if (!isSupported) return Future.value();
    return _plugin.cancel(id: habitNotificationId(habitId));
  }

  /// The next occurrence of [minuteOfDay] (0-1439) from now - today if
  /// that time hasn't passed yet, otherwise tomorrow. zonedSchedule needs
  /// a real starting instant even for a "matches the time every day"
  /// recurrence.
  tz.TZDateTime _nextOccurrence(int minuteOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Deterministic positive notification id derived from a habit's UUID -
/// fully reproducible from the id alone, so nothing needs to store a
/// separate mapping. `hashCode` can be negative; masked to fit
/// flutter_local_notifications' positive int id range. Collision risk is
/// negligible at this app's personal-planner scale (a handful of habits).
int habitNotificationId(String habitId) => habitId.hashCode & 0x7FFFFFFF;
