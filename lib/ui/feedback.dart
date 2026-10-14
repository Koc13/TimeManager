import 'package:flutter/material.dart';

/// Runs [action] and shows any error as a SnackBar instead of losing it.
/// File writes can fail (folder removed, unreadable file refused).
Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('$e')));
  }
}
