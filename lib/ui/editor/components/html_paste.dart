import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'callout_block_component.dart';
import 'code_block_component.dart';
import 'image_paste.dart';
import 'markdown_paste.dart';
import 'toggle_block_component.dart';

/// Encodes Notes Here's custom `code` block into semantic `<pre><code>` HTML
/// so copied code blocks paste cleanly back into Notes Here, Notion, or web apps.
class HTMLCodeBlockParser extends HTMLNodeParser {
  const HTMLCodeBlockParser();

  @override
  String get id => codeBlockType;

  @override
  String transformNodeToHTMLString(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) => toHTMLString(
    transformNodeToDomNodes(node, encodeParsers: encodeParsers),
  );

  @override
  List<dom.Node> transformNodeToDomNodes(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) {
    final code = node.delta?.toPlainText() ?? '';
    final language = (node.attributes['language'] as String?)?.trim() ?? '';
    final codeEl = dom.Element.tag('code')..text = code;
    if (language.isNotEmpty) {
      codeEl.attributes['class'] = 'language-$language';
    }
    final preEl = dom.Element.tag('pre')..append(codeEl);
    return [preEl];
  }
}

/// Encodes Notes Here's `callout` block into semantic `<aside>` HTML.
class HTMLCalloutNodeParser extends HTMLNodeParser {
  const HTMLCalloutNodeParser();

  @override
  String get id => calloutBlockType;

  @override
  String transformNodeToHTMLString(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) => toHTMLString(
    transformNodeToDomNodes(node, encodeParsers: encodeParsers),
  );

  @override
  List<dom.Node> transformNodeToDomNodes(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) {
    final icon = node.attributes[CalloutBlockKeys.icon]?.toString() ?? '💡';
    final p = dom.Element.tag('p')..text = node.delta?.toPlainText() ?? '';
    final aside = dom.Element.tag('aside')
      ..attributes['data-callout-icon'] = icon
      ..append(p);
    for (final child in node.children) {
      final parser = encodeParsers.where((e) => e.id == child.type).firstOrNull;
      if (parser != null) {
        aside.nodes.addAll(
          parser.transformNodeToDomNodes(child, encodeParsers: encodeParsers),
        );
      }
    }
    return [aside];
  }
}

/// Encodes Notes Here's `toggle` block into semantic `<details><summary>` HTML.
class HTMLToggleNodeParser extends HTMLNodeParser {
  const HTMLToggleNodeParser();

  @override
  String get id => toggleBlockType;

  @override
  String transformNodeToHTMLString(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) => toHTMLString(
    transformNodeToDomNodes(node, encodeParsers: encodeParsers),
  );

  @override
  List<dom.Node> transformNodeToDomNodes(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) {
    final collapsed = node.attributes[ToggleBlockKeys.collapsed] == true;
    final summary = dom.Element.tag('summary')
      ..text = node.delta?.toPlainText() ?? '';
    final details = dom.Element.tag('details')..append(summary);
    if (!collapsed) {
      details.attributes['open'] = '';
    }
    for (final child in node.children) {
      final parser = encodeParsers.where((e) => e.id == child.type).firstOrNull;
      if (parser != null) {
        details.nodes.addAll(
          parser.transformNodeToDomNodes(child, encodeParsers: encodeParsers),
        );
      }
    }
    return [details];
  }
}

/// Encodes base64-backed and URL-backed image nodes into `<img src="...">` HTML.
class HTMLImageDataUriParser extends HTMLNodeParser {
  const HTMLImageDataUriParser();

  @override
  String get id => ImageBlockKeys.type;

  @override
  String transformNodeToHTMLString(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) => toHTMLString(
    transformNodeToDomNodes(node, encodeParsers: encodeParsers),
  );

  @override
  List<dom.Node> transformNodeToDomNodes(
    Node node, {
    required List<HTMLNodeParser> encodeParsers,
  }) {
    final url = node.attributes[ImageBlockKeys.url]?.toString() ?? '';
    if (url.isEmpty) return const [];
    final resolvedSrc =
        url.startsWith('http://') ||
            url.startsWith('https://') ||
            url.startsWith('data:')
        ? url
        : 'data:${inferImageMimeTypeFromBase64(url)};base64,$url';
    final img = dom.Element.tag('img')..attributes['src'] = resolvedSrc;
    return [img];
  }
}

const Set<String> _ignoredTags = {
  'head',
  'meta',
  'title',
  'link',
  'style',
  'script',
  'noscript',
  'template',
  'svg',
};

const Set<String> _semanticTags = {
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'pre',
  'code',
  'kbd',
  'samp',
  'tt',
  'blockquote',
  'details',
  'aside',
  'table',
  'hr',
  'strong',
  'b',
  'em',
  'i',
  'u',
  's',
  'del',
  'strike',
  'a',
  'img',
};

const Set<String> _blockTags = {
  'p',
  'div',
  'section',
  'article',
  'main',
  'aside',
  'header',
  'footer',
  'nav',
  'figure',
  'figcaption',
  'form',
  'details',
  'summary',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'pre',
  'blockquote',
  'table',
  'hr',
};

/// Returns `true` when [html] contains semantic structure or rich formatting
/// (headings, lists, links, inline code, emphasis) rather than just plain
/// syntax-highlighted wrapper `<div>`/`<span>` tags.
bool hasRichSemanticHtml(String html) {
  if (html.trim().isEmpty) return false;
  final document = html_parser.parse(html);
  final body = document.body;
  if (body == null) return false;

  bool visit(dom.Element element) {
    final tag = element.localName;
    if (tag == null || _ignoredTags.contains(tag)) return false;
    if (_semanticTags.contains(tag)) {
      if (tag == 'a') {
        final href = element.attributes['href'];
        if (href != null && href.isNotEmpty) return true;
      } else if (tag == 'img') {
        final src = element.attributes['src'];
        if (src != null &&
            (src.startsWith('http') || stripDataImageUriBase64(src) != null)) {
          return true;
        }
      } else {
        return true;
      }
    }
    if (tag == 'input' &&
        element.attributes['type']?.toLowerCase() == 'checkbox') {
      return true;
    }
    if (_extractCssAttributes(element.attributes['style']).isNotEmpty) {
      return true;
    }
    return element.children.any(visit);
  }

  return body.children.any(visit);
}

/// Returns `true` when [html] contains semantic text/structure alongside or
/// instead of a standalone `<img>` tag (so copying a lone browser image uses
/// compressed clipboard image bytes rather than downloading/inserting HTML).
bool hasRichTextAlongsideImages(String html) {
  if (html.trim().isEmpty) return false;
  final nodes = htmlToEditorNodes(html);
  return nodes.any((node) => node.type != ImageBlockKeys.type);
}

/// Converts clipboard [html] into structured AppFlowy [Node]s while ignoring
/// web/chat theme CSS colors so pasted content adopts the Notes Here theme.
List<Node> htmlToEditorNodes(String html) {
  final document = html_parser.parse(html);
  final body = document.body;
  if (body == null) return const [];
  return trimEdgeEmptyParagraphs(_parseBlockNodes(body.nodes));
}

/// Parses [html] and inserts the resulting nodes into [editorState].
Future<bool> pasteHtmlText(
  EditorState editorState,
  String html,
) async {
  final nodes = htmlToEditorNodes(html);
  return pasteRichNodes(editorState, nodes);
}

List<Node> _parseBlockNodes(Iterable<dom.Node> domNodes) {
  final result = <Node>[];
  final inlineBuffer = _InlineAccumulator();

  void flushInlineParagraphs() {
    for (final delta in inlineBuffer.takeParagraphDeltas()) {
      result.add(paragraphNode(delta: delta));
    }
  }

  for (final domNode in domNodes) {
    if (domNode is dom.Text) {
      final text = domNode.text;
      if (text.trim().isEmpty) {
        if (inlineBuffer.hasContent && text.contains(RegExp(r'\s'))) {
          inlineBuffer.appendSpaceIfNeeded();
        }
        continue;
      }
      inlineBuffer.addText(text);
      continue;
    }

    if (domNode is! dom.Element) continue;
    final tag = domNode.localName;
    if (tag == null || _ignoredTags.contains(tag)) continue;

    if (tag == 'br') {
      inlineBuffer.lineBreak();
      continue;
    }

    if (_isBlockElement(domNode)) {
      flushInlineParagraphs();
      result.addAll(_parseSpecialBlockElement(domNode));
      continue;
    }

    // Inline formatting tags or non-block spans/containers
    _collectInlineElement(domNode, const {}, inlineBuffer);
  }

  flushInlineParagraphs();
  return result;
}

bool _isBlockElement(dom.Element element) {
  final tag = element.localName;
  if (tag == null) return false;
  if (_blockTags.contains(tag)) return true;
  if (tag == 'img') {
    final src = element.attributes['src'];
    if (src != null &&
        (src.startsWith('http') || stripDataImageUriBase64(src) != null)) {
      return true;
    }
  }
  return _containsBlockDescendant(element);
}

bool _containsBlockDescendant(dom.Element element) {
  for (final child in element.children) {
    final tag = child.localName;
    if (tag != null && !_ignoredTags.contains(tag)) {
      if (_blockTags.contains(tag) || _containsBlockDescendant(child)) {
        return true;
      }
    }
  }
  return false;
}

List<Node> _parseSpecialBlockElement(dom.Element element) {
  final tag = element.localName;
  switch (tag) {
    case 'h1':
      return _parseHeading(element, 1);
    case 'h2':
      return _parseHeading(element, 2);
    case 'h3':
      return _parseHeading(element, 3);
    case 'h4':
      return _parseHeading(element, 4);
    case 'h5':
      return _parseHeading(element, 5);
    case 'h6':
      return _parseHeading(element, 6);
    case 'ul':
      return _parseList(element, ordered: false);
    case 'ol':
      return _parseList(element, ordered: true);
    case 'li':
      return [_parseListItem(element, ordered: false)];
    case 'pre':
      return [_parsePreCodeBlock(element)];
    case 'blockquote':
      return _parseBlockQuote(element);
    case 'details':
      return [_parseDetailsToggle(element)];
    case 'aside':
      return [_parseAsideCallout(element)];
    case 'hr':
      return [dividerNode()];
    case 'table':
      final tableNode = _parseTable(element);
      return tableNode == null ? const [] : [tableNode];
    case 'img':
      final src = element.attributes['src'];
      if (src == null || src.isEmpty) return const [];
      final base64Data = stripDataImageUriBase64(src);
      if (base64Data != null) {
        return [imageNode(url: base64Data)];
      }
      if (src.startsWith('http')) {
        return [imageNode(url: src)];
      }
      return const [];
    case 'p':
      if (_containsBlockDescendant(element)) {
        return _parseBlockNodes(element.nodes);
      }
      final acc = _InlineAccumulator();
      _collectInlineChildren(element.nodes, const {}, acc);
      return [
        for (final delta in acc.takeParagraphDeltas())
          paragraphNode(delta: delta),
      ];
    default:
      // div, section, article, span containing blocks, etc.
      if (_containsBlockDescendant(element)) {
        return _parseBlockNodes(element.nodes);
      }
      final acc = _InlineAccumulator();
      _collectInlineChildren(element.nodes, const {}, acc);
      return [
        for (final delta in acc.takeParagraphDeltas())
          paragraphNode(delta: delta),
      ];
  }
}

List<Node> _parseHeading(dom.Element element, int level) {
  final acc = _InlineAccumulator();
  _collectInlineChildren(element.nodes, const {}, acc);
  final delta = acc.toSingleDelta();
  return [headingNode(level: level, delta: delta)];
}

List<Node> _parseList(dom.Element element, {required bool ordered}) {
  final items = <Node>[];
  for (final child in element.children) {
    final tag = child.localName;
    if (tag == 'li') {
      items.add(_parseListItem(child, ordered: ordered));
    } else if (tag == 'ul' || tag == 'ol') {
      items.addAll(_parseList(child, ordered: tag == 'ol'));
    }
  }
  return items;
}

Node _parseListItem(dom.Element li, {required bool ordered}) {
  final checkbox = _findLeadingCheckbox(li);
  final nodeType = checkbox != null
      ? TodoListBlockKeys.type
      : (ordered ? NumberedListBlockKeys.type : BulletedListBlockKeys.type);

  final leadAcc = _InlineAccumulator();
  final nestedBlocks = <Node>[];
  var consumedPrimaryLine = false;

  for (final child in li.nodes) {
    if (child is dom.Text) {
      final text = child.text;
      if (text.trim().isEmpty) {
        if (!consumedPrimaryLine &&
            leadAcc.hasContent &&
            text.contains(RegExp(r'\s'))) {
          leadAcc.appendSpaceIfNeeded();
        }
        continue;
      }
      leadAcc.addText(text);
      continue;
    }

    if (child is! dom.Element) continue;
    final tag = child.localName;
    if (tag == null || _ignoredTags.contains(tag)) continue;

    if (tag == 'input' &&
        child.attributes['type']?.toLowerCase() == 'checkbox') {
      continue;
    }

    if (tag == 'ul' || tag == 'ol') {
      consumedPrimaryLine = true;
      nestedBlocks.addAll(_parseList(child, ordered: tag == 'ol'));
      continue;
    }

    if (tag == 'pre' ||
        tag == 'blockquote' ||
        tag == 'table' ||
        tag == 'hr' ||
        tag == 'h1' ||
        tag == 'h2' ||
        tag == 'h3' ||
        tag == 'h4' ||
        tag == 'h5' ||
        tag == 'h6') {
      consumedPrimaryLine = true;
      nestedBlocks.addAll(_parseSpecialBlockElement(child));
      continue;
    }

    if (tag == 'p' || tag == 'div') {
      if (_containsBlockDescendant(child)) {
        final subBlocks = _parseBlockNodes(child.nodes);
        for (final block in subBlocks) {
          if (!consumedPrimaryLine &&
              !leadAcc.hasContent &&
              block.type == ParagraphBlockKeys.type &&
              block.delta != null) {
            consumedPrimaryLine = true;
            leadAcc.appendDelta(block.delta!);
          } else {
            nestedBlocks.add(block);
          }
        }
      } else if (!consumedPrimaryLine && !leadAcc.hasContent) {
        consumedPrimaryLine = true;
        _collectInlineChildren(child.nodes, const {}, leadAcc);
      } else {
        nestedBlocks.addAll(_parseSpecialBlockElement(child));
      }
      continue;
    }

    _collectInlineElement(child, const {}, leadAcc);
  }

  final delta = leadAcc.toSingleDelta();
  return Node(
    type: nodeType,
    children: nestedBlocks,
    attributes: {
      ParagraphBlockKeys.delta: delta.toJson(),
      TodoListBlockKeys.checked: ?checkbox,
    },
  );
}

bool? _findLeadingCheckbox(dom.Element li) {
  for (final child in li.children) {
    final tag = child.localName;
    if (tag == 'input' &&
        child.attributes['type']?.toLowerCase() == 'checkbox') {
      return child.attributes.containsKey('checked');
    }
    if (tag == 'label' || tag == 'p' || tag == 'div' || tag == 'span') {
      for (final nested in child.children) {
        if (nested.localName == 'input' &&
            nested.attributes['type']?.toLowerCase() == 'checkbox') {
          return nested.attributes.containsKey('checked');
        }
      }
    }
  }
  return null;
}

Node _parsePreCodeBlock(dom.Element pre) {
  final codeElement = pre.children.where((c) => c.localName == 'code').firstOrNull;
  final language = _extractCodeLanguage(codeElement) ??
      _extractCodeLanguage(pre) ??
      'plaintext';

  final buffer = StringBuffer();
  void writeNode(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    if (tag == null || _ignoredTags.contains(tag)) return;
    if (tag == 'br') {
      buffer.write('\n');
      return;
    }
    final isLineBlock = tag == 'div' || tag == 'p';
    for (final child in node.nodes) {
      writeNode(child);
    }
    if (isLineBlock && !buffer.toString().endsWith('\n')) {
      buffer.write('\n');
    }
  }

  writeNode(codeElement ?? pre);
  var code = buffer.toString().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (code.endsWith('\n')) {
    code = code.substring(0, code.length - 1);
  }

  return codeBlockNode(
    language: language,
    delta: Delta()..insert(code),
  );
}

String? _extractCodeLanguage(dom.Element? element) {
  if (element == null) return null;
  final dataLang =
      element.attributes['data-language'] ?? element.attributes['data-lang'];
  if (dataLang != null && dataLang.trim().isNotEmpty) {
    return dataLang.trim().toLowerCase();
  }
  final className = element.attributes['class'] ?? '';
  final match = RegExp(r'(?:language|lang)-([a-zA-Z0-9_+#-]+)')
      .firstMatch(className);
  return match?.group(1)?.toLowerCase();
}

List<Node> _parseBlockQuote(dom.Element element) {
  final blocks = _parseBlockNodes(element.nodes);
  if (blocks.isEmpty) {
    return [quoteNode(delta: Delta())];
  }
  if (blocks.first.type == ParagraphBlockKeys.type && blocks.first.delta != null) {
    return [
      quoteNode(
        delta: blocks.first.delta,
        children: blocks.skip(1),
      ),
    ];
  }
  return [quoteNode(delta: Delta(), children: blocks)];
}

Node _parseDetailsToggle(dom.Element details) {
  final summaryEl =
      details.children.where((c) => c.localName == 'summary').firstOrNull;
  Delta summaryDelta = Delta();
  if (summaryEl != null) {
    final acc = _InlineAccumulator();
    _collectInlineChildren(summaryEl.nodes, const {}, acc);
    summaryDelta = acc.toSingleDelta();
  }
  final remainingNodes = details.nodes.where((n) => n != summaryEl);
  final childBlocks = trimEdgeEmptyParagraphs(_parseBlockNodes(remainingNodes));
  return toggleNode(
    collapsed: !details.attributes.containsKey('open'),
    delta: summaryDelta,
    children: childBlocks,
  );
}

Node _parseAsideCallout(dom.Element aside) {
  final icon = aside.attributes['data-callout-icon']?.trim();
  final blocks = trimEdgeEmptyParagraphs(_parseBlockNodes(aside.nodes));
  if (blocks.isNotEmpty &&
      blocks.first.type == ParagraphBlockKeys.type &&
      blocks.first.delta != null) {
    return calloutNode(
      icon: icon != null && icon.isNotEmpty ? icon : '💡',
      delta: blocks.first.delta,
      children: blocks.skip(1),
    );
  }
  return calloutNode(
    icon: icon != null && icon.isNotEmpty ? icon : '💡',
    delta: Delta(),
    children: blocks,
  );
}

Node? _parseTable(dom.Element table) {
  final rows = <dom.Element>[];
  void collectRows(dom.Element parent) {
    for (final child in parent.children) {
      final tag = child.localName;
      if (tag == 'tr') {
        rows.add(child);
      } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
        collectRows(child);
      }
    }
  }

  collectRows(table);
  final rowCellsList = rows
      .map(
        (row) => row.children
            .where((c) => c.localName == 'th' || c.localName == 'td')
            .toList(),
      )
      .where((cells) => cells.isNotEmpty)
      .toList();
  if (rowCellsList.isEmpty) {
    return null;
  }

  var maxCols = 0;
  for (final rowCells in rowCellsList) {
    if (rowCells.length > maxCols) {
      maxCols = rowCells.length;
    }
  }
  if (maxCols == 0) {
    return null;
  }

  final cells = <Node>[];
  for (var r = 0; r < rowCellsList.length; r++) {
    final rowCells = rowCellsList[r];
    for (var c = 0; c < maxCols; c++) {
      final cellBlocks = c < rowCells.length
          ? _parseBlockNodes(rowCells[c].nodes)
          : const <Node>[];
      cells.add(
        Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.colPosition: c,
            TableCellBlockKeys.rowPosition: r,
          },
          children: cellBlocks.isEmpty ? [paragraphNode()] : cellBlocks,
        ),
      );
    }
  }

  return TableNode(
    node: Node(
      type: TableBlockKeys.type,
      attributes: {
        TableBlockKeys.rowsLen: rowCellsList.length,
        TableBlockKeys.colsLen: maxCols,
        TableBlockKeys.colDefaultWidth: TableDefaults.colWidth,
        TableBlockKeys.rowDefaultHeight: TableDefaults.rowHeight,
        TableBlockKeys.colMinimumWidth: TableDefaults.colMinimumWidth,
      },
      children: cells,
    ),
  ).node;
}

void _collectInlineChildren(
  Iterable<dom.Node> domNodes,
  Map<String, dynamic> inheritedAttributes,
  _InlineAccumulator acc,
) {
  for (final node in domNodes) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.trim().isEmpty) {
        if (acc.hasContent && text.contains(RegExp(r'\s'))) {
          acc.appendSpaceIfNeeded(attributes: inheritedAttributes);
        }
        continue;
      }
      acc.addText(text, attributes: inheritedAttributes);
      continue;
    }
    if (node is dom.Element) {
      _collectInlineElement(node, inheritedAttributes, acc);
    }
  }
}

void _collectInlineElement(
  dom.Element element,
  Map<String, dynamic> inheritedAttributes,
  _InlineAccumulator acc,
) {
  final tag = element.localName;
  if (tag == null || _ignoredTags.contains(tag)) return;

  if (tag == 'br') {
    acc.lineBreak();
    return;
  }

  if (tag == 'input' &&
      element.attributes['type']?.toLowerCase() == 'checkbox') {
    return;
  }

  final merged = Map<String, dynamic>.from(inheritedAttributes);
  switch (tag) {
    case 'strong':
    case 'b':
      merged[AppFlowyRichTextKeys.bold] = true;
    case 'em':
    case 'i':
      merged[AppFlowyRichTextKeys.italic] = true;
    case 'u':
      merged[AppFlowyRichTextKeys.underline] = true;
    case 's':
    case 'del':
    case 'strike':
      merged[AppFlowyRichTextKeys.strikethrough] = true;
    case 'code':
    case 'kbd':
    case 'samp':
    case 'tt':
      merged[AppFlowyRichTextKeys.code] = true;
    case 'a':
      final href = element.attributes['href'];
      if (href != null && href.isNotEmpty) {
        merged[AppFlowyRichTextKeys.href] = href;
      }
  }

  final cssAttrs = _extractCssAttributes(element.attributes['style']);
  merged.addAll(cssAttrs);

  _collectInlineChildren(element.nodes, merged, acc);
}

Map<String, dynamic> _extractCssAttributes(String? style) {
  if (style == null || style.isEmpty) return const {};
  final attrs = <String, dynamic>{};
  for (final entry in style.split(';')) {
    final colonIndex = entry.indexOf(':');
    if (colonIndex <= 0) continue;
    final prop = entry.substring(0, colonIndex).trim().toLowerCase();
    final value = entry.substring(colonIndex + 1).trim().toLowerCase();
    switch (prop) {
      case 'font-weight':
        if (value == 'bold' || value == 'bolder') {
          attrs[AppFlowyRichTextKeys.bold] = true;
        } else {
          final weight = int.tryParse(value);
          if (weight != null && weight >= 600) {
            attrs[AppFlowyRichTextKeys.bold] = true;
          }
        }
      case 'font-style':
        if (value == 'italic' || value == 'oblique') {
          attrs[AppFlowyRichTextKeys.italic] = true;
        }
      case 'text-decoration':
      case 'text-decoration-line':
        if (value.contains('underline')) {
          attrs[AppFlowyRichTextKeys.underline] = true;
        }
        if (value.contains('line-through')) {
          attrs[AppFlowyRichTextKeys.strikethrough] = true;
        }
    }
  }
  return attrs;
}

class _InlineRun {
  _InlineRun(this.text, this.attributes);

  String text;
  final Map<String, dynamic> attributes;
}

class _InlineAccumulator {
  final List<List<_InlineRun>> _lines = [<_InlineRun>[]];

  List<_InlineRun> get _current => _lines.last;

  bool get hasContent => _current.isNotEmpty;

  void addText(String rawText, {Map<String, dynamic> attributes = const {}}) {
    var normalized = rawText
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return;

    if (_current.isEmpty) {
      normalized = normalized.trimLeft();
    } else if (_current.last.text.endsWith(' ') &&
        normalized.startsWith(' ')) {
      normalized = normalized.substring(1);
    }

    if (normalized.isEmpty) return;
    _pushRun(normalized, attributes);
  }

  void appendSpaceIfNeeded({Map<String, dynamic> attributes = const {}}) {
    if (_current.isEmpty || _current.last.text.endsWith(' ')) return;
    _pushRun(' ', attributes);
  }

  void appendDelta(Delta delta) {
    for (final op in delta) {
      if (op is TextInsert && op.text.isNotEmpty) {
        _pushRun(op.text, op.attributes ?? const {});
      }
    }
  }

  void lineBreak() {
    if (_current.isNotEmpty || _lines.length > 1) {
      _lines.add(<_InlineRun>[]);
    }
  }

  void _pushRun(String text, Map<String, dynamic> attributes) {
    final normalizedAttrs =
        attributes.isEmpty ? const <String, dynamic>{} : attributes;
    if (_current.isNotEmpty &&
        _mapsEqual(_current.last.attributes, normalizedAttrs)) {
      _current.last.text += text;
    } else {
      _current.add(_InlineRun(text, normalizedAttrs));
    }
  }

  List<Delta> takeParagraphDeltas() {
    final result = <Delta>[];
    for (final line in _lines) {
      final delta = _runsToTrimmedDelta(line);
      if (delta.isNotEmpty) {
        result.add(delta);
      }
    }
    _lines
      ..clear()
      ..add(<_InlineRun>[]);
    return result;
  }

  Delta toSingleDelta() {
    final merged = <_InlineRun>[];
    for (final line in _lines) {
      if (merged.isNotEmpty &&
          line.isNotEmpty &&
          !merged.last.text.endsWith(' ')) {
        merged.add(_InlineRun(' ', const {}));
      }
      merged.addAll(line);
    }
    return _runsToTrimmedDelta(merged);
  }

  Delta _runsToTrimmedDelta(List<_InlineRun> runs) {
    if (runs.isEmpty) return Delta();
    final copy = runs
        .map((r) => _InlineRun(r.text, r.attributes))
        .toList(growable: true);

    while (copy.isNotEmpty) {
      copy.first.text = copy.first.text.trimLeft();
      if (copy.first.text.isEmpty) {
        copy.removeAt(0);
      } else {
        break;
      }
    }
    while (copy.isNotEmpty) {
      copy.last.text = copy.last.text.trimRight();
      if (copy.last.text.isEmpty) {
        copy.removeLast();
      } else {
        break;
      }
    }

    final delta = Delta();
    for (final run in copy) {
      if (run.text.isEmpty) continue;
      delta.insert(
        run.text,
        attributes: run.attributes.isEmpty ? null : run.attributes,
      );
    }
    return delta;
  }

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
