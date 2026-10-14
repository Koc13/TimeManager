import 'dart:async';
import 'dart:io';

import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/period_doc.dart';
import 'package:first_app/domain/task.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:first_app/storage/folder_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('tm_watch'));
  tearDown(() => dir.delete(recursive: true));

  test(
    'reports files changed in nested folders, ignoring hidden ones',
    () async {
      Directory('${dir.path}/periods/2026/10').createSync(recursive: true);
      final changes = StreamController<Set<String>>();
      final watcher = FolderWatcher(dir.path, changes.add);
      await watcher.start();
      addTearDown(watcher.stop);

      File('${dir.path}/periods/2026/10/.x.md.tmp').writeAsStringSync('temp');
      File('${dir.path}/periods/2026/10/2026-10-14.md').writeAsStringSync('x');
      final paths = await changes.stream.first.timeout(
        const Duration(seconds: 3),
      );
      expect(paths, {'periods/2026/10/2026-10-14.md'});
    },
  );

  test('the store tells its own writes apart from outside edits', () async {
    final store = await DataStore.open(dir.path);
    final day = Day(DateTime(2026, 10, 14));
    await store.savePeriods([
      PeriodDoc(
        period: day,
        tasks: [Task(id: 't_1', title: 'A', created: DateTime(2026, 10, 14))],
      ),
    ]);
    const path = 'periods/2026/10/2026-10-14.md';
    expect(await store.changedOnDisk({path}), isFalse);

    final file = File('${dir.path}/$path');
    file.writeAsStringSync(file.readAsStringSync().replaceAll('A', 'B'));
    expect(await store.changedOnDisk({path}), isTrue);

    expect(
      await store.changedOnDisk({'goals/g_new.md'}),
      isFalse,
      reason: 'a file that does not exist and was never known',
    );
    expect(
      await store.changedOnDisk({'periods/2026/10/x.sync-conflict-1.md'}),
      isTrue,
    );
  });
}
