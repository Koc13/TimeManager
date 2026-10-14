import 'dart:convert';
import 'dart:io';

/// Settings that belong to this device only, kept in the app's private
/// folder, never in the synced data root: the data root's own path (it
/// differs per device) and, later, the running timer.
class LocalSettings {
  LocalSettings(this._file);

  final File _file;

  Future<Map<String, Object?>> _read() async {
    if (!await _file.exists()) return {};
    try {
      return jsonDecode(await _file.readAsString()) as Map<String, Object?>;
    } on FormatException {
      return {};
    }
  }

  Future<void> _update(String key, Object? value) async {
    final map = await _read()
      ..[key] = value;
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(map), flush: true);
  }

  Future<String?> dataRoot() async => (await _read())['data_root'] as String?;

  Future<void> setDataRoot(String? path) => _update('data_root', path);

  /// The running timer as JSON, or null when idle.
  Future<Object?> timer() async => (await _read())['timer'];

  Future<void> setTimer(Map<String, Object?>? json) => _update('timer', json);
}
