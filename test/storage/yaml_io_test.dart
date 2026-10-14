import 'package:first_app/storage/yaml_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strings that YAML would misread are quoted, others stay plain', () {
    final map = <String, Object?>{
      'plain': 'Pattern Recognition (Bishop)',
      'comma': 'Clean room, every Sunday',
      'bool': 'true',
      'number': '42',
      'null': 'null',
      'colon': 'a: b',
      'comment': 'x #y',
      'dash': '- item',
      'multiline': 'line 1\nline 2',
      'padded': ' x ',
      'empty': '',
      'date': '2026-10-14',
      'time': '2026-10-14T20:00:00+02:00',
    };
    final text = writeYamlMap(map);
    expect(readYamlMap(text), map);
    expect(text, contains('plain: Pattern Recognition (Bishop)\n'));
    expect(text, contains('comma: Clean room, every Sunday\n'));
    expect(text, contains('bool: "true"\n'));
    expect(text, contains('date: 2026-10-14\n'));
  });

  test('lists of maps are block style, small maps and scalar lists flow', () {
    final map = <String, Object?>{
      'tasks': [
        {
          'id': 't_1',
          'link': {'type': 'goal', 'id': 'g_1'},
          'days': [1, 3],
        },
        {'id': 't_2', 'link': null},
      ],
      'empty': <Object?>[],
      'flow': {'type': 'custom', 'name': 'Tax, forms'},
    };
    const expected = '''
tasks:
  - id: t_1
    link: {type: goal, id: g_1}
    days: [1, 3]
  - id: t_2
    link: null
empty: []
flow: {type: custom, name: "Tax, forms"}
''';
    expect(writeYamlMap(map), expected);
    expect(readYamlMap(expected), map);
  });

  test('timestamps and dates stay strings when read', () {
    final map = readYamlMap('a: 2026-10-14\nb: 2026-10-14T20:00:00+02:00\n');
    expect(map['a'], isA<String>());
    expect(map['b'], isA<String>());
  });

  group('markdown frontmatter', () {
    test('splits and rejoins byte for byte', () {
      const text = '---\ntitle: x\n---\n# Journal\n\n---\nnot frontmatter\n';
      final doc = readMarkdown(text);
      expect(doc.frontmatter, {'title': 'x'});
      expect(doc.body, '# Journal\n\n---\nnot frontmatter\n');
      expect(writeMarkdown(doc.frontmatter, doc.body), text);
    });

    test('a file without frontmatter is all body', () {
      final doc = readMarkdown('just notes\n');
      expect(doc.frontmatter, isEmpty);
      expect(doc.body, 'just notes\n');
    });

    test('empty frontmatter and closing fence at end of file', () {
      expect(readMarkdown('---\n---\nbody').body, 'body');
      expect(readMarkdown('---\na: 1\n---').frontmatter, {'a': 1});
    });

    test('unclosed frontmatter is an error, not silently body', () {
      expect(() => readMarkdown('---\na: 1\n'), throwsFormatException);
    });
  });
}
