import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager/domain/plan_reminders.dart';
import 'package:time_manager/notifications/notification_service.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/providers/plan_reminders.dart';
import 'package:time_manager/storage/local_settings.dart';

class Recorder extends NoNotifications {
  final scheduled = <int, (String, DateTime, Repeat)>{};

  @override
  Future<void> schedule({
    required int id,
    required ReminderChannel channel,
    required String title,
    required String body,
    required DateTime at,
    required String payload,
    Repeat repeat = Repeat.none,
  }) async => scheduled[id] = (payload, at, repeat);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tm_plan'));
  tearDown(() => dir.delete(recursive: true));

  test('defaults schedule all six; monthly ones three ahead', () async {
    final notifications = Recorder();
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 9)),
        notificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(c.dispose);
    await c.read(planRemindersProvider.notifier).reschedule();

    final byPayload = <String, List<(DateTime, Repeat)>>{};
    for (final (payload, at, repeat) in notifications.scheduled.values) {
      (byPayload[payload] ??= []).add((at, repeat));
    }
    expect(byPayload['open:day'], hasLength(2));
    expect(byPayload['open:day']!.every((e) => e.$2 == Repeat.daily), isTrue);
    expect(byPayload['open:week']!.map((e) => e.$2), [
      Repeat.weekly,
      Repeat.weekly,
    ]);
    expect(byPayload['open:month'], hasLength(6), reason: '2 reminders × 3');
    expect(
      byPayload['open:month']!.map((e) => e.$1),
      containsAll([DateTime(2026, 10, 31, 20), DateTime(2026, 11, 1, 8)]),
    );
  });

  test('turning one off cancels it and the change is remembered', () async {
    final notifications = Recorder();
    final settings = LocalSettings(File('${dir.path}/local.json'));
    final c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 15, 9)),
        notificationsProvider.overrideWithValue(notifications),
        localSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(c.dispose);
    final reminders = c.read(planRemindersProvider.notifier);
    await reminders.reschedule();
    await reminders.set(
      PlanReminder.dayReview,
      PlanReminder.dayReview.defaultTime.copyWith(enabled: false),
    );
    expect(
      notifications.scheduled.containsKey(planNotificationId(1, 0)),
      isFalse,
    );
    expect(
      notifications.scheduled.containsKey(planNotificationId(0, 0)),
      isTrue,
    );

    // A fresh start reads the stored settings.
    final c2 = ProviderContainer(
      overrides: [
        restoredPlanRemindersProvider.overrideWithValue(
          await settings.planReminders(),
        ),
      ],
    );
    addTearDown(c2.dispose);
    expect(
      c2.read(planRemindersProvider)[PlanReminder.dayReview]!.enabled,
      isFalse,
    );
  });
}
