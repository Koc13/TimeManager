import 'dart:io';

import 'package:time_manager/domain/period.dart';
import 'package:time_manager/domain/period_doc.dart';
import 'package:time_manager/domain/task.dart';
import 'package:time_manager/notifications/notification_service.dart';
import 'package:time_manager/providers/data_providers.dart';
import 'package:time_manager/providers/reminder_sync.dart';
import 'package:time_manager/storage/data_store.dart';
import 'package:time_manager/storage/local_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingNotifications extends NoNotifications {
  final calls = <String>[];

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime at,
  }) async => calls.add('schedule $taskId ${at.hour}:${at.minute}');

  @override
  Future<void> cancelTaskReminder(String taskId) async =>
      calls.add('cancel $taskId');
}

void main() {
  late Directory dir;
  late DataStore store;
  late LocalSettings settings;
  late RecordingNotifications notifications;
  final now = DateTime(2026, 10, 14, 9);
  final today = Day(now);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm_rem');
    store = await DataStore.open('${dir.path}/data');
    settings = LocalSettings(File('${dir.path}/local.json'));
    notifications = RecordingNotifications();
  });
  tearDown(() => dir.delete(recursive: true));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        dataStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
        localSettingsProvider.overrideWithValue(settings),
        notificationsProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  Task task({int hour = 19, DateTime? doneAt}) => Task(
    id: 't_1',
    title: 'Trash',
    created: now,
    reminder: DateTime(2026, 10, 14, hour),
    doneAt: doneAt,
  );

  test('schedules, reschedules on change, cancels when done', () async {
    final c = container();
    c.read(reminderSyncProvider);
    final data = c.read(appDataProvider.notifier);

    await data.saveTask(today, task());
    await settle();
    expect(notifications.calls, ['schedule t_1 19:0']);

    await data.saveTask(today, task(hour: 20));
    await settle();
    expect(notifications.calls.skip(1), ['cancel t_1', 'schedule t_1 20:0']);

    await data.saveTask(today, task(hour: 20, doneAt: now));
    await settle();
    expect(notifications.calls.last, 'cancel t_1');
  });

  test('a restart does not reschedule what is already scheduled', () async {
    await store.savePeriods([
      PeriodDoc(period: today, tasks: [task()]),
    ]);
    final first = container();
    first.read(reminderSyncProvider);
    await settle();
    expect(notifications.calls, ['schedule t_1 19:0']);

    final second = container();
    second.read(reminderSyncProvider);
    await settle();
    expect(notifications.calls, hasLength(1));
  });

  test(
    'a reminder removed by an outside edit is cancelled on reload',
    () async {
      final c = container();
      c.read(reminderSyncProvider);
      await c.read(appDataProvider.notifier).saveTask(today, task());
      await settle();

      final file = File('${dir.path}/data/periods/2026/10/2026-10-14.md');
      file.writeAsStringSync(
        file.readAsStringSync().replaceFirst(
          RegExp(r'reminder: .*'),
          'reminder: null',
        ),
      );
      await c.read(appDataProvider.notifier).reload();
      await settle();
      expect(notifications.calls.last, 'cancel t_1');
    },
  );
}
