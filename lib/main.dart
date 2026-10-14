import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'storage/local_settings.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final private = await getApplicationSupportDirectory();
  final settings = LocalSettings(File('${private.path}/local_settings.json'));
  runApp(TimeManagerApp(settings: settings));
}
