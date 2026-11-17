import 'package:appflowy_editor/appflowy_editor.dart';

import '../../../services/export_import_service.dart';

final List<RegExp> _markdownDetectionPatterns = [
  // Headings: # Heading
  RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+\S', multiLine: true),
  // Unordered / todo lists: - item, * item, + item, - [ ] task
  RegExp(r'^[ \t]*[-*+][ \t]+\S', multiLine: true),
  // Ordered lists: 1. item
  RegExp(r'^[ \t]*\d{1,9}\.[ \t]+\S', multiLine: true),
  // Blockquotes: > quote
  RegExp(r'^[ \t]*>[ \t]+\S', multiLine: true),
  // Fenced code blocks: ``` or ~~~
  RegExp(r'^[ \t]*(?:`{3,}|~{3,})', multiLine: true),
  // Horizontal rules / dividers: ---, ***, ___
  RegExp(r'^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$', multiLine: true),
  // Markdown tables: | --- | --- |
  RegExp(
    r'^[ \t]*\|?(?:[ \t]*:?-{3,}:?[ \t]*\|)+[ \t]*:?-{3,}:?[ \t]*\|?[ \t]*$',
    multiLine: true,
  ),
  // Inline code: `code`
  RegExp(r'`[^`\n]+`'),
  // Bold: **text** or __text__
  RegExp(r'\*\*[^*\n]+\*\*|__[^_\n]+__'),
  // Italic: *text* (avoid matching stray multiplication or **)
  RegExp(r'(?<!\*)\*(?!\s|\*)[^*\n]+(?<!\s)\*(?!\*)'),
  // Strikethrough: ~~text~~
  RegExp(r'~~[^~\n]+~~'),
  // Links: [label](url)
  RegExp(r'\[[^\]\n]+\]\((?:https?://|page://|mailto:)[^\s)\n]+\)'),
];

/// Returns true when [rawText] contains Markdown block or inline syntax that
/// should be parsed into structured editor nodes/formatting on paste.
bool looksLikeMarkdown(String rawText) {
  final normalized = _normalizeLineEndings(rawText).trim();
  if (normalized.isEmpty) {
    return false;
  }
  return _markdownDetectionPatterns.any((pattern) => pattern.hasMatch(normalized));
}

/// Parses [rawText] as Markdown and inserts the resulting rich nodes at the
/// current selection in [editorState]. Returns `false` if nothing could be
/// parsed so the caller can fall back to standard plain-text paste.
Future<bool> pasteMarkdownText(
  EditorState editorState,
  String rawText,
) async {
  if (editorState.selection == null) {
    return false;
  }

  final normalized = _normalizeLineEndings(rawText);
  final document = markdownToDocument(
    normalized,
    markdownParsers: const [MarkdownCodeBlockParser()],
  );
  final nodes = trimEdgeEmptyParagraphs(document.root.children.toList());
  return pasteRichNodes(editorState, nodes);
}

/// Inserts parsed rich [nodes] into [editorState] at the active selection.
/// Single plain paragraphs are pasted inline via `pasteSingleLineNode`, single
/// non-paragraph blocks replace an empty paragraph or insert after the current
/// block, and multi-block content uses `pasteMultiLineNodes`.
Future<bool> pasteRichNodes(
  EditorState editorState,
  List<Node> rawNodes,
) async {
  final selection = editorState.selection;
  if (selection == null) {
    return false;
  }
  final nodes = trimEdgeEmptyParagraphs(rawNodes);
  if (nodes.isEmpty) {
    return false;
  }

  if (nodes.length == 1) {
    final single = nodes.first;
    if (single.type == ParagraphBlockKeys.type && single.children.isEmpty) {
      await editorState.pasteSingleLineNode(single);
      return true;
    }

    await editorState.deleteSelectionIfNeeded();
    final currentSelection = editorState.selection;
    if (currentSelection == null) {
      return false;
    }
    final currentNode = editorState.getNodeAtPath(currentSelection.start.path);
    if (currentNode == null) {
      return false;
    }

    final transaction = editorState.transaction;
    final replaceEmpty = _isEmptyParagraph(currentNode);
    final targetPath = replaceEmpty ? currentNode.path : currentNode.path.next;
    transaction.insertNode(targetPath, single);
    if (replaceEmpty) {
      transaction.deleteNode(currentNode);
    }
    final delta = single.delta;
    transaction.afterSelection = Selection.collapsed(
      Position(path: targetPath, offset: delta?.length ?? 0),
    );
    await editorState.apply(transaction);
    return true;
  }

  // AppFlowy's pasteMultiLineNodes only replaces an empty current paragraph when
  // nodes.first has a delta. When multi-block paste starts with a non-delta
  // block (divider, table, image), replace the empty paragraph explicitly.
  if (nodes.first.delta == null) {
    await editorState.deleteSelectionIfNeeded();
    final currentSelection = editorState.selection;
    if (currentSelection != null && currentSelection.isCollapsed) {
      final currentNode = editorState.getNodeAtPath(
        currentSelection.start.path,
      );
      if (currentNode != null && _isEmptyParagraph(currentNode)) {
        final basePath = currentNode.path;
        final transaction = editorState.transaction;
        for (var i = 0; i < nodes.length; i++) {
          transaction.insertNode([...basePath.parent, basePath.last + i], nodes[i]);
        }
        transaction.deleteNode(currentNode);
        final lastPath = [...basePath.parent, basePath.last + nodes.length - 1];
        transaction.afterSelection = Selection.collapsed(
          Position(path: lastPath, offset: nodes.last.delta?.length ?? 0),
        );
        await editorState.apply(transaction);
        return true;
      }
    }
  }

  await editorState.pasteMultiLineNodes(nodes);
  return true;
}

String _normalizeLineEndings(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

/// Strips leading and trailing empty paragraph nodes produced by decoders.
List<Node> trimEdgeEmptyParagraphs(List<Node> nodes) {
  var start = 0;
  var end = nodes.length;
  while (start < end && _isEmptyParagraph(nodes[start])) {
    start++;
  }
  while (end > start && _isEmptyParagraph(nodes[end - 1])) {
    end--;
  }
  return nodes.sublist(start, end);
}

bool _isEmptyParagraph(Node node) =>
    node.type == ParagraphBlockKeys.type &&
    (node.delta?.isEmpty ?? true) &&
    node.children.isEmpty;
