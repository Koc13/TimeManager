import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class FolderAccessDenied implements Exception {
  @override
  String toString() => 'Allow "All files access" to use a folder.';
}

/// Asks for storage access (Android) and lets the user pick a folder.
/// Returns null if the picker was cancelled.
///
/// Android: the folder lives in shared storage (so Syncthing can sync it)
/// and is read with plain dart:io, which needs "All files access".
Future<String?> pickDataFolder() async {
  if (Platform.isAndroid &&
      !await Permission.manageExternalStorage.request().isGranted) {
    throw FolderAccessDenied();
  }
  return FilePicker.getDirectoryPath(dialogTitle: 'Data folder');
}
