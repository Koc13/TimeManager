import 'dart:io';

import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/period_doc.dart';
import 'package:first_app/domain/task.dart';
import 'package:first_app/notifications/notification_service.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:first_app/storage/local_settings.dart';
import 'package:first_app/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('tm_settings'));
  tearDown(() => dir.delete(recursive: true));

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  testWidgets('changing the data folder reopens the app on it', (tester) async {
    final a = '${dir.path}/a';
    final b = '${dir.path}/b';
    final settings = LocalSettings(File('${dir.path}/local.json'));
    final today = Day(DateTime.now());
    await tester.runAsync(() async {
      await settings.setDataRoot(a);
      await (await DataStore.open(a)).savePeriods([
        PeriodDoc(
          period: today,
          tasks: [Task(id: 't_a', title: 'Task in A', created: DateTime.now())],
        ),
      ]);
      await (await DataStore.open(b)).savePeriods([
        PeriodDoc(
          period: today,
          tasks: [Task(id: 't_b', title: 'Task in B', created: DateTime.now())],
        ),
      ]);
    });

    await tester.pumpWidget(
      TimeManagerApp(
        settings: settings,
        notifications: const NoNotifications(),
        pickFolder: () async => b,
      ),
    );
    await settleIo(tester);
    expect(find.text('Task in A'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text(a), findsOneWidget);

    await tester.tap(find.text('Change'));
    await settleIo(tester);
    expect(find.text('Task in B'), findsOneWidget, reason: 'back on the ToDo');
    expect(await tester.runAsync(settings.dataRoot), b);
  });
}
