/// Reading and writing the YAML subset this app stores: maps, lists,
/// strings, numbers, bools and null.
///
/// Why a hand-written writer: package:yaml only parses. The writer emits
/// one canonical layout (block maps, block lists of maps, flow style for
/// small maps/lists of scalars like `{type: goal, id: g_x}`), so writing a
/// parsed canonical file reproduces it byte for byte. YAML comments are not
/// kept, since the parsed data has no place for them.
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

/// Parses [text] into plain Dart maps/lists. Empty text gives an empty map.
Map<String, Object?> readYamlMap(String text) {
  final node = loadYaml(text);
  if (node == null) return {};
  if (node is! Map) throw const FormatException('Frontmatter is not a map');
  return _plain(node) as Map<String, Object?>;
}

Object? _plain(Object? node) => switch (node) {
  Map() => {for (final e in node.entries) e.key.toString(): _plain(e.value)},
  List() => [for (final item in node) _plain(item)],
  _ => node,
};

/// Writes [map] as a block-style YAML document ending in a newline.
String writeYamlMap(Map<String, Object?> map) {
  final out = StringBuffer();
  _writeMap(out, map, 0);
  return out.toString();
}

void _writeMap(StringBuffer out, Map<String, Object?> map, int indent) {
  final pad = '  ' * indent;
  for (final MapEntry(:key, :value) in map.entries) {
    final k = _key(key);
    if (value is Map<String, Object?> && !_isFlow(value)) {
      out.writeln('$pad$k:');
      _writeMap(out, value, indent + 1);
    } else if (value is List && !_isFlow(value)) {
      out.writeln('$pad$k:');
      for (final item in value) {
        _writeListItem(out, item, indent + 1);
      }
    } else {
      out.writeln('$pad$k: ${_inline(value)}');
    }
  }
}

// A map item is written as a block map one level deeper, then its first
// line's indentation is swapped for "- " (both are two characters wide):
//   "    id: t_1"  ->  "  - id: t_1"
void _writeListItem(StringBuffer out, Object? item, int indent) {
  final pad = '  ' * indent;
  if (item is Map<String, Object?> && item.isNotEmpty) {
    final inner = StringBuffer();
    _writeMap(inner, item, indent + 1);
    out.write('$pad- ${inner.toString().substring(pad.length + 2)}');
  } else {
    out.writeln('$pad- ${_inline(item)}');
  }
}

// Empty collections and collections of scalars only go on one line.
bool _isFlow(Object value) => switch (value) {
  Map() => value.values.every(_isScalar),
  List() => value.every(_isScalar),
  _ => true,
};

bool _isScalar(Object? value) => value is! Map && value is! List;

String _inline(Object? value) => switch (value) {
  null => 'null',
  bool() || int() => '$value',
  double() => '$value',
  String() => _string(value, flow: false),
  Map() =>
    '{${value.entries.map((e) => '${_key(e.key.toString())}: ${_flowScalar(e.value)}').join(', ')}}',
  List() => '[${value.map(_flowScalar).join(', ')}]',
  _ => throw ArgumentError('Cannot write ${value.runtimeType} as YAML'),
};

String _flowScalar(Object? value) =>
    value is String ? _string(value, flow: true) : _inline(value);

// A string is written plain (unquoted) only if reading it back gives the
// same string. That one check covers every YAML trap at once: "true",
// "null", "42", "a: b", "x #comment", leading "-", "[", "*"...
String _string(String s, {required bool flow}) {
  if (_readsBackAs(s, flow ? '[$s]' : 'k: $s', flow)) return s;
  // JSON string syntax is valid YAML double-quoted syntax.
  return jsonEncode(s);
}

String _key(String key) =>
    _readsBackAs(key, '$key: 0', null) ? key : jsonEncode(key);

bool _readsBackAs(String s, String probe, bool? flow) {
  if (s.isEmpty || s.trim() != s || s.contains('\n')) return false;
  try {
    final parsed = loadYaml(probe);
    return switch (flow) {
      true => parsed is List && parsed.length == 1 && parsed.first == s,
      false => parsed is Map && parsed.length == 1 && parsed['k'] == s,
      null => parsed is Map && parsed.length == 1 && parsed.keys.first == s,
    };
  } catch (_) {
    return false;
  }
}

/// A Markdown file with optional YAML frontmatter.
typedef MarkdownDoc = ({Map<String, Object?> frontmatter, String body});

/// Splits `---\n<yaml>---\n<body>`. A file without frontmatter is all body.
MarkdownDoc readMarkdown(String text) {
  if (!text.startsWith('---\n')) return (frontmatter: {}, body: text);
  // Search from index 3 so an empty frontmatter ("---\n---\n") matches the
  // newline ending the opening fence.
  final close = text.indexOf('\n---\n', 3);
  if (close == -1) {
    if (text.endsWith('\n---')) {
      return (
        frontmatter: readYamlMap(text.substring(4, text.length - 3)),
        body: '',
      );
    }
    throw const FormatException('Frontmatter has no closing ---');
  }
  return (
    frontmatter: readYamlMap(text.substring(4, close + 1)),
    body: text.substring(close + 5),
  );
}

String writeMarkdown(Map<String, Object?> frontmatter, String body) =>
    '---\n${writeYamlMap(frontmatter)}---\n$body';
