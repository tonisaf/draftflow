import 'dart:io';
import 'package:flutter/foundation.dart';

Future<void> openExternalUrl(String url) async {
  try {
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isWindows) {
      await Process.run('start', ['', url], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  } catch (e) {
    debugPrint('Failed to open external url $url: $e');
  }
}
