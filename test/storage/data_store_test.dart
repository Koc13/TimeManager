import 'dart:io';

import 'package:first_app/domain/goal.dart';
import 'package:first_app/domain/period.dart';
import 'package:first_app/domain/period_doc.dart';
import 'package:first_app/domain/task.dart';
import 'package:first_app/storage/data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  String root() => dir.path;

  setUp(() async => dir = await Directory.systemTemp.createTemp('tm_store'));
  tearDown(() => dir.delete(recursive: true));

  PeriodDoc dayWithTask(String title) => PeriodDoc(
    period: DayPeriod(DateTime(2026, 10, 14)),
    tasks: [Task(id: 't_1', title: title, created: DateTime(2026, 10, 14, 8))],
  );

  test('first open creates the versioned config file', () async {
    await DataStore.open(root());
    expect(
      File('${root()}/.timemanager.yaml').readAsStringSync(),
      'format_version: 1\n',
    );
  });

  test('a newer format version is refused', () async {
    File('${root()}/.timemanager.yaml')
        .writeAsStringSync('format_version: 2\n');
    expect(DataStore.open(root()), throwsA(isA<UnsupportedFormatException>()));
  });

  test('saved records land at their documented paths and load back', () async {
    final store = await DataStore.open(root());
    await store.savePeriods([
      dayWithTask('Trash'),
      PeriodDoc.empty(const WeekPeriod(2026, 53)),
      PeriodDoc.empty(const MonthPeriod(2026, 10)),
    ]);
    await store.saveGoal(
      Goal(id: 'g_1', title: 'Read', created: DateTime(2026)),
    );

    for (final path in [
      'periods/2026/10/2026-10-14.md',
      'periods/2026/2026-W53.md',
      'periods/2026/2026-10.md',
      'goals/g_1.md',
    ]) {
      expect(File('${root()}/$path').existsSync(), isTrue, reason: path);
    }
    // No temp files left behind by the atomic write.
    final leftovers = dir
        .listSync(recursive: true)
        .where((e) => e.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);

    final reopened = await DataStore.open(root());
    expect(
      reopened.data
          .period(DayPeriod(DateTime(2026, 10, 14)))
          .tasks
          .single
          .title,
      'Trash',
    );
    expect(reopened.data.goals['g_1']!.title, 'Read');
  });

  test('unchanged files are not rewritten', () async {
    final store = await DataStore.open(root());
    await store.savePeriods([dayWithTask('Trash')]);
    final file = File('${root()}/periods/2026/10/2026-10-14.md');
    final before = file.lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    file.setLastModifiedSync(before); // make any rewrite detectable
    await store.savePeriods([dayWithTask('Trash')]);
    expect(file.lastModifiedSync(), before);
  });

  test('external edits win on reload', () async {
    final store = await DataStore.open(root());
    await store.savePeriods([dayWithTask('Trash')]);
    final file = File('${root()}/periods/2026/10/2026-10-14.md');
    file.writeAsStringSync(file.readAsStringSync().replaceAll('Trash', 'Bins'));
    await store.reload();
    expect(
      store.data.period(DayPeriod(DateTime(2026, 10, 14))).tasks.single.title,
      'Bins',
    );
  });

  test('conflict copies are listed and never parsed', () async {
    Directory('${root()}/periods/2026/10').createSync(recursive: true);
    File(
      '${root()}/periods/2026/10/2026-10-14.sync-conflict-20261014-120000-ABCDEFG.md',
    ).writeAsStringSync('---\ntasks:\n  - Ghost\n---\n');
    final store = await DataStore.open(root());
    expect(store.conflicts, hasLength(1));
    expect(store.data.periods, isEmpty);
  });

  test(
    'a file that fails to parse is reported and never overwritten',
    () async {
      final path = '${root()}/periods/2026/10/2026-10-14.md';
      Directory('${root()}/periods/2026/10').createSync(recursive: true);
      File(path).writeAsStringSync('---\ntasks: [unclosed\n---\n');
      final store = await DataStore.open(root());
      expect(store.loadErrors.keys, ['periods/2026/10/2026-10-14.md']);
      expect(
        store.savePeriods([dayWithTask('Trash')]),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(path).readAsStringSync(), '---\ntasks: [unclosed\n---\n');
    },
  );

  test('markdown files that are not ours are ignored', () async {
    Directory('${root()}/periods').createSync(recursive: true);
    File('${root()}/periods/ideas.md').writeAsStringSync('# Ideas\n');
    final store = await DataStore.open(root());
    expect(store.data.periods, isEmpty);
    expect(store.loadErrors, isEmpty);
  });
}
