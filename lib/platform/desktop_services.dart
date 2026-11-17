import 'dart:io' show Platform, File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;

const macosSidebarWidth = 248.0;
const _macosWindow = MethodChannel('notes_here/macos_window');
bool _acrylicReady = false;

Future<bool> applyBackdrop({required bool dark}) async {
  if (Platform.isWindows) {
    final build =
        int.tryParse(
          RegExp(r'Build (\d+)')
                  .firstMatch(Platform.operatingSystemVersion)
                  ?.group(1) ??
              '',
        ) ??
        0;
    if (build < 22000) return false;
    try {
      if (!_acrylicReady) {
        await acrylic.Window.initialize();
        _acrylicReady = true;
      }
      await acrylic.Window.setEffect(
        effect: build >= 22523
            ? acrylic.WindowEffect.tabbed
            : acrylic.WindowEffect.mica,
        dark: dark,
      );
      return true;
    } on Object {
      return false;
    }
  }
  if (!Platform.isMacOS) return false;
  try {
    return await _macosWindow.invokeMethod<bool>('setSidebarBackdrop', {
          'dark': dark,
        }) ??
        false;
  } on Object {
    return false;
  }
}

/// Reads rich HTML (`public.html` / `NSPasteboardTypeHTML`) from the desktop
/// pasteboard when copied from browsers, Electron apps, or chat clients.
Future<String?> readClipboardHtml() async {
  try {
    final html = await _macosWindow.invokeMethod<String>('getClipboardHtml');
    if (html == null || html.isEmpty) return null;
    return html;
  } on Object {
    return null;
  }
}

/// Writes both plain [text] and optional rich [html] onto the desktop
/// pasteboard so copied blocks keep their structure in Notion and browsers.
Future<bool> writeClipboardData({String? text, String? html}) async {
  try {
    return await _macosWindow.invokeMethod<bool>('setClipboardData', {
          'text': text,
          'html': html,
        }) ??
        false;
  } on Object {
    return false;
  }
}

/// Reads and compresses image bytes (PNG/JPEG screenshots or copied image files)
/// from the desktop pasteboard.
Future<List<Uint8List>> readClipboardImages() async {
  try {
    final raw = await _macosWindow.invokeMethod<List<Object?>>(
      'getClipboardImages',
    );
    if (raw == null || raw.isEmpty) return const [];
    return raw.whereType<Uint8List>().where((b) => b.isNotEmpty).toList();
  } on Object {
    return const [];
  }
}

/// Coordinates native macOS Finder/image drag-and-drop events sent over
/// `notes_here/macos_window`. Uses a LIFO handler list so modal/peek editors
/// restore the underlying page editor's handler when closed.
abstract final class DesktopImageDropBridge {
  static final ValueNotifier<bool> isHovering = ValueNotifier(false);
  static final List<void Function(List<Uint8List> images)> _handlers = [];
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _macosWindow.setMethodCallHandler(_handleNativeCall);
  }

  static void registerDropHandler(
    void Function(List<Uint8List> images) handler,
  ) {
    ensureInitialized();
    _handlers.remove(handler);
    _handlers.add(handler);
  }

  static void unregisterDropHandler(
    void Function(List<Uint8List> images) handler,
  ) {
    _handlers.remove(handler);
    if (_handlers.isEmpty) {
      isHovering.value = false;
    }
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onImageDragState':
        final args = call.arguments as Map<dynamic, dynamic>?;
        isHovering.value = args?['hovering'] == true;
        return null;
      case 'onImagesDropped':
        isHovering.value = false;
        final args = call.arguments as Map<dynamic, dynamic>?;
        final rawImages = args?['images'] as List<Object?>?;
        if (rawImages == null || rawImages.isEmpty) return null;
        final images =
            rawImages.whereType<Uint8List>().where((b) => b.isNotEmpty).toList();
        if (images.isNotEmpty && _handlers.isNotEmpty) {
          _handlers.last.call(images);
        }
        return null;
      default:
        return null;
    }
  }
}

class DesktopFilePicker {
  /// Opens a native OS file dialog to select a file.
  /// Returns the absolute path of the chosen file, or null if cancelled.
  static Future<String?> pickFile({
    List<String> allowedExtensions = const ['csv', 'md', 'txt'],
    String prompt = 'Select File to Import',
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: prompt,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );
      return result?.files.singleOrNull?.path;
    } catch (_) {
      return null;
    }
  }
}

/// The native save dialog is kept behind the desktop platform boundary.
Future<bool> saveRecoveryBackup(String json) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Сохранить резервную копию',
    fileName: 'notes-recovery.json',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (path == null) return false;
  await File(path).writeAsString(json);
  return true;
}
