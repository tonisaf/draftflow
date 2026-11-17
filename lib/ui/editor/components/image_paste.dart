import 'dart:convert';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';

import 'markdown_paste.dart';

final RegExp _dataImageUriRegex = RegExp(
  r'^data:image/[a-zA-Z0-9+.-]+;base64,(.+)$',
  caseSensitive: false,
  dotAll: true,
);

/// Extracts raw base64 payload from a `data:image/...;base64,...` URI so
/// AppFlowy's `ResizableImage` (`isBase64` + `base64Decode`) can render it.
String? stripDataImageUriBase64(String src) {
  final trimmed = src.trim();
  final match = _dataImageUriRegex.firstMatch(trimmed);
  if (match == null) return null;
  final raw = match.group(1)!.replaceAll(RegExp(r'\s+'), '');
  if (raw.isEmpty) return null;
  try {
    base64Decode(raw);
    return raw;
  } catch (_) {
    return null;
  }
}

/// Sniffs common image magic bytes (PNG/JPEG/GIF/WebP) to reconstruct a valid
/// `data:image/...;base64,...` URI for HTML/Markdown export.
String inferImageMimeTypeFromBase64(String rawBase64) {
  try {
    final decoded = base64Decode(rawBase64);
    return inferImageMimeType(decoded);
  } catch (_) {
    return 'image/png';
  }
}

String inferImageMimeType(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/png';
}

/// Converts compressed [images] bytes into base64-backed [imageNode] blocks.
List<Node> imageNodesFromBytes(List<Uint8List> images) => [
  for (final bytes in images)
    if (bytes.isNotEmpty) imageNode(url: base64Encode(bytes)),
];

/// Inserts compressed [images] into [editorState] at the active selection, or
/// appends them to the document if dropped while the editor is unfocused.
Future<bool> pasteImageBytes(
  EditorState editorState,
  List<Uint8List> images,
) async {
  if (editorState.isDisposed || !editorState.editable || images.isEmpty) {
    return false;
  }
  final nodes = imageNodesFromBytes(images);
  if (nodes.isEmpty) return false;

  if (editorState.selection != null) {
    return pasteRichNodes(editorState, nodes);
  }

  final rootChildren = editorState.document.root.children;
  final transaction = editorState.transaction;
  if (rootChildren.length == 1 &&
      rootChildren.first.type == ParagraphBlockKeys.type &&
      (rootChildren.first.delta?.isEmpty ?? true) &&
      rootChildren.first.children.isEmpty) {
    final only = rootChildren.first;
    for (var i = 0; i < nodes.length; i++) {
      transaction.insertNode([i], nodes[i]);
    }
    transaction.deleteNode(only);
    transaction.afterSelection = Selection.collapsed(
      Position(path: [nodes.length - 1]),
    );
  } else {
    final startIndex = rootChildren.length;
    for (var i = 0; i < nodes.length; i++) {
      transaction.insertNode([startIndex + i], nodes[i]);
    }
    transaction.afterSelection = Selection.collapsed(
      Position(path: [startIndex + nodes.length - 1]),
    );
  }
  await editorState.apply(transaction);
  return true;
}
