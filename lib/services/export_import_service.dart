import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' as drift;
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';

import '../data/db/app_database.dart';
import '../data/notes_repository.dart';
import '../ui/editor/components/callout_block_component.dart';
import '../ui/editor/components/code_block_component.dart';
import '../ui/editor/components/database/database_models.dart';
import '../ui/editor/components/image_paste.dart';
import '../ui/editor/components/page_link_block_component.dart';
import '../ui/editor/components/toggle_block_component.dart';

/// Custom parser that converts fenced code blocks into notes_here code block nodes.
class MarkdownCodeBlockParser extends CustomMarkdownParser {
  const MarkdownCodeBlockParser();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element || element.tag != 'pre') return [];
    final ec = element.children;
    if (ec == null || ec.isEmpty) return [];
    final code = ec.first;
    if (code is! md.Element || code.tag != 'code') return [];

    String language = 'plaintext';
    if (code.attributes.containsKey('class')) {
      final classes = code.attributes['class']!.split(' ');
      final languageClass = classes.firstWhere(
        (c) => c.startsWith('language-'),
        orElse: () => '',
      );
      if (languageClass.length > 'language-'.length) {
        language = languageClass.substring('language-'.length);
      }
    }

    return [
      codeBlockNode(
        language: language,
        delta: Delta()..insert(code.textContent.trimRight()),
      ),
    ];
  }
}

class ParsedMarkdownPage {
  final String? title;
  final String? icon;
  final String? cover;
  final DateTime? createdAt;
  final Document document;

  const ParsedMarkdownPage({
    this.title,
    this.icon,
    this.cover,
    this.createdAt,
    required this.document,
  });
}

class NotionCsvColumnInfo {
  final String name;
  final String type; // 'title', 'number', 'date', 'select', 'url', 'checkbox', 'text'
  final List<String> distinctValues;

  const NotionCsvColumnInfo({
    required this.name,
    required this.type,
    required this.distinctValues,
  });

  NotionCsvColumnInfo copyWith({
    String? name,
    String? type,
    List<String>? distinctValues,
  }) {
    return NotionCsvColumnInfo(
      name: name ?? this.name,
      type: type ?? this.type,
      distinctValues: distinctValues ?? this.distinctValues,
    );
  }
}

class ParsedCsvDatabase {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final int titleColumnIndex;
  final List<NotionCsvColumnInfo> columns;

  const ParsedCsvDatabase({
    required this.title,
    required this.headers,
    required this.rows,
    required this.titleColumnIndex,
    required this.columns,
  });

  ParsedCsvDatabase copyWith({
    String? title,
    List<String>? headers,
    List<List<String>>? rows,
    int? titleColumnIndex,
    List<NotionCsvColumnInfo>? columns,
  }) {
    return ParsedCsvDatabase(
      title: title ?? this.title,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      titleColumnIndex: titleColumnIndex ?? this.titleColumnIndex,
      columns: columns ?? this.columns,
    );
  }
}

class WorkspaceRestoreSummary {
  final int pagesCount;
  final int blocksCount;
  final int databasesCount;
  final int columnsCount;

  const WorkspaceRestoreSummary({
    required this.pagesCount,
    required this.blocksCount,
    required this.databasesCount,
    required this.columnsCount,
  });
}

class ExportImportService {
  final NotesRepository repository;

  const ExportImportService({required this.repository});

  // ---------------------------------------------------------------------------
  // Markdown Export
  // ---------------------------------------------------------------------------

  /// Exports a single page and all its blocks (including database tables) to Markdown.
  Future<String> exportPageToMarkdown(String pageId) async {
    final page = await repository.getPage(pageId);
    final document = await repository.loadPageDocument(pageId);

    final sb = StringBuffer();

    // 1. Frontmatter
    sb.writeln('---');
    sb.writeln('title: ${_yamlEscape(page?.title ?? 'Untitled')}');
    if (page?.icon != null && page!.icon!.isNotEmpty) {
      sb.writeln('icon: ${_yamlEscape(page.icon!)}');
    }
    if (page?.cover != null && page!.cover!.isNotEmpty) {
      sb.writeln('cover: ${_yamlEscape(page.cover!)}');
    }
    if (page?.createdAt != null) {
      sb.writeln('createdAt: ${page!.createdAt.toIso8601String()}');
    }
    sb.writeln('---');
    sb.writeln();

    // 2. Document title as H1 header
    final title = page?.title.trim().isNotEmpty == true ? page!.title.trim() : 'Untitled';
    sb.writeln('# $title\n');

    // 3. Process nodes
    for (final node in document.root.children) {
      if (node.type == databaseBlockType) {
        final dbId = node.attributes['databaseId']?.toString();
        if (dbId != null && dbId.isNotEmpty) {
          final dbMarkdown = await _exportDatabaseToMarkdown(dbId);
          sb.writeln(dbMarkdown);
          sb.writeln();
        }
      } else if (node.type == calloutBlockType) {
        final icon = node.attributes[CalloutBlockKeys.icon]?.toString() ?? '💡';
        final text = _nodeInlineMarkdown(node);
        sb.writeln('> $icon${text.isEmpty ? '' : ' $text'}');
        for (final child in node.children) {
          final childMd = _exportChildMarkdown(child).trim();
          if (childMd.isNotEmpty) {
            for (final line in childMd.split('\n')) {
              sb.writeln('> $line');
            }
          }
        }
        sb.writeln();
      } else if (node.type == toggleBlockType) {
        final summary = _nodeInlineMarkdown(node);
        sb.writeln('<details>');
        sb.writeln('<summary>$summary</summary>');
        for (final child in node.children) {
          final childMd = _exportChildMarkdown(child).trim();
          if (childMd.isNotEmpty) {
            sb.writeln();
            sb.writeln(childMd);
          }
        }
        sb.writeln();
        sb.writeln('</details>');
        sb.writeln();
      } else if (node.type == pageLinkBlockType) {
        final title = node.attributes[PageLinkBlockKeys.title]?.toString() ?? 'Untitled';
        final pageId = node.attributes[PageLinkBlockKeys.pageId]?.toString() ?? '';
        final icon = node.attributes[PageLinkBlockKeys.icon]?.toString();
        final iconPrefix = (icon != null && icon.isNotEmpty) ? '$icon ' : '';
        sb.writeln('[$iconPrefix$title](page://$pageId)');
        sb.writeln();
      } else if (node.type == ImageBlockKeys.type) {
        final url = node.attributes[ImageBlockKeys.url]?.toString() ?? '';
        if (url.isNotEmpty) {
          final isUri =
              url.startsWith('http://') ||
              url.startsWith('https://') ||
              url.startsWith('data:') ||
              url.startsWith('/');
          final resolved = isUri
              ? url
              : 'data:${inferImageMimeTypeFromBase64(url)};base64,$url';
          sb.writeln('![image]($resolved)');
          sb.writeln();
        }
      } else {
        final singleDoc = Document(root: pageNode(children: [node]));
        final mdStr = documentToMarkdown(singleDoc).trim();
        if (mdStr.isNotEmpty) {
          sb.writeln(mdStr);
          sb.writeln();
        }
      }
    }

    return sb.toString().trimRight();
  }

  String _nodeInlineMarkdown(Node node) {
    final doc = Document(
      root: pageNode(
        children: [paragraphNode(delta: node.delta)],
      ),
    );
    return documentToMarkdown(doc).trim();
  }

  String _exportChildMarkdown(Node node) {
    final doc = Document(root: pageNode(children: [node]));
    return documentToMarkdown(doc).trim();
  }

  Future<String> _exportDatabaseToMarkdown(String databaseId) async {
    final db = await repository.getDatabase(databaseId);
    final cols = await repository.getColumns(databaseId);
    final rows = await repository.getDatabaseRows(databaseId);

    final sb = StringBuffer();
    final dbTitle = db?.title.trim().isNotEmpty == true ? db!.title.trim() : 'Table';
    sb.writeln('### 📊 $dbTitle\n');

    // Headers: Name + additional columns
    final headers = <String>['Name'];
    for (final col in cols) {
      if (col.type != 'title') {
        headers.add(col.name);
      }
    }

    sb.writeln('| ${headers.map(_escapeMarkdownCell).join(' | ')} |');
    sb.writeln('| ${headers.map((_) => '---').join(' | ')} |');

    for (final row in rows) {
      final cells = <String>[_escapeMarkdownCell(row.title)];
      Map<String, dynamic> props = {};
      if (row.properties != null && row.properties!.isNotEmpty) {
        try {
          props = (jsonDecode(row.properties!) as Map).cast<String, dynamic>();
        } catch (_) {}
      }

      for (final col in cols) {
        if (col.type == 'title') continue;
        final val = props[col.id];
        cells.add(_formatCellValue(val, col));
      }

      sb.writeln('| ${cells.join(' | ')} |');
    }

    return sb.toString();
  }

  String _formatCellValue(dynamic val, DatabaseColumn col) {
    if (val == null) return '';
    if (col.type == 'checkbox') {
      return (val == true || val == 'true' || val == 1) ? '[x]' : '[ ]';
    }
    if (col.type == 'url') {
      final text = val.toString().trim();
      if (text.isEmpty) return '';
      final link = text.startsWith('http://') || text.startsWith('https://')
          ? text
          : 'https://$text';
      return '[${_escapeMarkdownCell(text)}]($link)';
    }
    if (col.type == 'number') {
      final num? numVal =
          val is num ? val : num.tryParse(val.toString().trim());
      if (numVal != null) {
        final config = NumberColumnConfig.fromOptions(col.options);
        return _escapeMarkdownCell(formatNumberValue(numVal, config));
      }
    }
    if ((col.type == 'select' || col.type == 'status') && col.options != null) {
      try {
        final optionsList = (jsonDecode(col.options!) as List).cast<Map>();
        final match = optionsList.firstWhere(
          (o) => o['id'] == val,
          orElse: () => {},
        );
        if (match['label'] != null) {
          return _escapeMarkdownCell(match['label'].toString());
        }
      } catch (_) {}
    }
    if (col.type == 'multi_select' && col.options != null) {
      try {
        final optionsList = (jsonDecode(col.options!) as List).cast<Map>();
        final labelMap = {
          for (final o in optionsList)
            o['id'].toString(): o['label'].toString(),
        };
        if (val is List) {
          final labels = val
              .map((id) => labelMap[id.toString()] ?? id.toString())
              .toList();
          return _escapeMarkdownCell(labels.join(', '));
        }
      } catch (_) {}
    }
    return _escapeMarkdownCell(val.toString());
  }

  String _escapeMarkdownCell(String text) {
    return text.replaceAll('|', r'\|').replaceAll('\n', ' ').trim();
  }

  String _yamlEscape(String value) {
    if (value.contains(':') ||
        value.contains('\n') ||
        value.contains('"') ||
        value.contains("'")) {
      return jsonEncode(value);
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // Markdown Import
  // ---------------------------------------------------------------------------

  /// Parses Markdown with optional frontmatter into a [ParsedMarkdownPage].
  ParsedMarkdownPage parseMarkdown(String rawMarkdown) {
    String content = rawMarkdown;
    String? title;
    String? icon;
    String? cover;
    DateTime? createdAt;

    // Check for YAML frontmatter
    final frontmatterMatch = RegExp(
      r'^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)',
    ).firstMatch(content);

    if (frontmatterMatch != null) {
      final yaml = frontmatterMatch.group(1)!;
      content = content.substring(frontmatterMatch.end).trim();

      for (final line in yaml.split(RegExp(r'\r?\n'))) {
        final colonIdx = line.indexOf(':');
        if (colonIdx > 0) {
          final key = line.substring(0, colonIdx).trim().toLowerCase();
          var val = line.substring(colonIdx + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) ||
              (val.startsWith("'") && val.endsWith("'"))) {
            val = val.substring(1, val.length - 1);
          }
          if (key == 'title') title = val;
          if (key == 'icon') icon = val;
          if (key == 'cover') cover = val;
          if (key == 'createdat') {
            createdAt = DateTime.tryParse(val);
          }
        }
      }
    }

    // If no title from frontmatter, check for leading H1
    if (title == null || title.isEmpty) {
      final lines = content.split(RegExp(r'\r?\n'));
      for (int i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.startsWith('# ')) {
          title = trimmed.substring(2).trim();
          // Remove the H1 line so it's not duplicated in editor body
          lines.removeAt(i);
          content = lines.join('\n').trim();
          break;
        } else if (trimmed.isNotEmpty) {
          break;
        }
      }
    }

    Document doc;
    if (content.isEmpty) {
      doc = Document(root: pageNode(children: [paragraphNode()]));
    } else {
      doc = markdownToDocument(
        content,
        markdownParsers: const [MarkdownCodeBlockParser()],
      );
      if (doc.root.children.isEmpty) {
        doc = Document(root: pageNode(children: [paragraphNode()]));
      }
    }

    return ParsedMarkdownPage(
      title: title,
      icon: icon,
      cover: cover,
      createdAt: createdAt,
      document: doc,
    );
  }

  /// Imports Markdown as a brand-new Page in the repository.
  Future<String> importMarkdownAsNewPage(
    String rawMarkdown, {
    String? parentId,
    String? fallbackTitle,
  }) async {
    final parsed = parseMarkdown(rawMarkdown);
    final title = parsed.title?.trim().isNotEmpty == true
        ? parsed.title!.trim()
        : (fallbackTitle ?? 'Imported Note');

    final newPageId = await repository.createPage(
      title: title,
      parentId: parentId,
      icon: parsed.icon,
      cover: parsed.cover,
    );

    final nodes = parsed.document.root.children.toList();
    if (nodes.isNotEmpty) {
      await repository.savePageNodes(newPageId, nodes);
    }

    return newPageId;
  }

  // ---------------------------------------------------------------------------
  // Workspace JSON Backup & Restore
  // ---------------------------------------------------------------------------

  /// Creates a full workspace backup JSON containing all pages, blocks, databases, and columns.
  Future<String> exportWorkspaceJson() async {
    final pages = await repository.db.getAllPages();
    final blocks = await repository.db.getAllBlocks();
    final databases = await repository.db.getAllDatabases();
    final columns = await repository.db.getAllDatabaseColumns();

    final data = {
      'format': 'notes_here_workspace_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'pages': pages
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'parentId': p.parentId,
                'icon': p.icon,
                'cover': p.cover,
                'orderKey': p.orderKey,
                'databaseId': p.databaseId,
                'properties': p.properties,
                'createdAt': p.createdAt.toIso8601String(),
                'trashedAt': p.trashedAt?.toIso8601String(),
                'trashBatchId': p.trashBatchId,
              })
          .toList(),
      'blocks': blocks
          .map((b) => {
                'id': b.id,
                'pageId': b.pageId,
                'parentId': b.parentId,
                'type': b.type,
                'content': b.content,
                'orderKey': b.orderKey,
                'trashedAt': b.trashedAt?.toIso8601String(),
                'trashBatchId': b.trashBatchId,
              })
          .toList(),
      'databases': databases
          .map((d) => {
                'id': d.id,
                'title': d.title,
                'icon': d.icon,
                'parentPageId': d.parentPageId,
                'createdAt': d.createdAt.toIso8601String(),
                'trashedAt': d.trashedAt?.toIso8601String(),
                'trashBatchId': d.trashBatchId,
              })
          .toList(),
      'databaseColumns': columns
          .map((c) => {
                'id': c.id,
                'databaseId': c.databaseId,
                'name': c.name,
                'type': c.type,
                'options': c.options,
                'width': c.width,
                'orderKey': c.orderKey,
                'createdAt': c.createdAt.toIso8601String(),
              })
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Restores a full workspace backup JSON string.
  Future<WorkspaceRestoreSummary> restoreWorkspaceJson(
    String jsonString, {
    bool wipeExisting = false,
  }) async {
    final Map<String, dynamic> data =
        (jsonDecode(jsonString) as Map).cast<String, dynamic>();

    if (data['format'] != 'notes_here_workspace_backup') {
      throw const FormatException('Invalid workspace backup format');
    }

    final pagesData = (data['pages'] as List? ?? []).cast<Map>();
    final blocksData = (data['blocks'] as List? ?? []).cast<Map>();
    final databasesData = (data['databases'] as List? ?? []).cast<Map>();
    final columnsData = (data['databaseColumns'] as List? ?? []).cast<Map>();

    final pagesList = pagesData.map((m) {
      return PagesCompanion(
        id: drift.Value(m['id'].toString()),
        title: drift.Value(m['title']?.toString() ?? ''),
        parentId: drift.Value(m['parentId']?.toString()),
        icon: drift.Value(m['icon']?.toString()),
        cover: drift.Value(m['cover']?.toString()),
        orderKey: drift.Value(m['orderKey']?.toString()),
        databaseId: drift.Value(m['databaseId']?.toString()),
        properties: drift.Value(m['properties']?.toString()),
        createdAt: drift.Value(DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()),
        trashedAt: drift.Value(m['trashedAt'] != null ? DateTime.tryParse(m['trashedAt'].toString()) : null),
        trashBatchId: drift.Value(m['trashBatchId']?.toString()),
      );
    }).toList();

    final blocksList = blocksData.map((m) {
      return BlocksCompanion(
        id: drift.Value(m['id'].toString()),
        pageId: drift.Value(m['pageId'].toString()),
        parentId: drift.Value(m['parentId']?.toString()),
        type: drift.Value(m['type'].toString()),
        content: drift.Value(m['content'].toString()),
        orderKey: drift.Value(m['orderKey'].toString()),
        trashedAt: drift.Value(m['trashedAt'] != null ? DateTime.tryParse(m['trashedAt'].toString()) : null),
        trashBatchId: drift.Value(m['trashBatchId']?.toString()),
      );
    }).toList();

    final databasesList = databasesData.map((m) {
      return DatabasesCompanion(
        id: drift.Value(m['id'].toString()),
        title: drift.Value(m['title']?.toString() ?? 'Untitled Database'),
        icon: drift.Value(m['icon']?.toString()),
        parentPageId: drift.Value(m['parentPageId']?.toString()),
        createdAt: drift.Value(DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()),
        trashedAt: drift.Value(m['trashedAt'] != null ? DateTime.tryParse(m['trashedAt'].toString()) : null),
        trashBatchId: drift.Value(m['trashBatchId']?.toString()),
      );
    }).toList();

    final columnsList = columnsData.map((m) {
      return DatabaseColumnsCompanion(
        id: drift.Value(m['id'].toString()),
        databaseId: drift.Value(m['databaseId'].toString()),
        name: drift.Value(m['name'].toString()),
        type: drift.Value(m['type'].toString()),
        options: drift.Value(m['options']?.toString()),
        width: drift.Value((m['width'] as num?)?.toDouble() ?? 160.0),
        orderKey: drift.Value(m['orderKey'].toString()),
        createdAt: drift.Value(DateTime.tryParse(m['createdAt'].toString()) ?? DateTime.now()),
      );
    }).toList();

    await repository.db.restoreWorkspaceData(
      pagesList: pagesList,
      blocksList: blocksList,
      databasesList: databasesList,
      columnsList: columnsList,
      wipeExisting: wipeExisting,
    );

    return WorkspaceRestoreSummary(
      pagesCount: pagesList.length,
      blocksCount: blocksList.length,
      databasesCount: databasesList.length,
      columnsCount: columnsList.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Notion / CSV Database Import
  // ---------------------------------------------------------------------------

  static const List<String> notionTagColors = [
    '0xFF4A90E2', // Blue
    '0xFFF5A623', // Orange
    '0xFF7ED321', // Green
    '0xFF9013FE', // Purple
    '0xFFD0021B', // Red
    '0xFF50E3C2', // Teal
    '0xFFF8E71C', // Yellow
    '0xFFBD10E0', // Magenta
    '0xFF8B572A', // Brown
    '0xFF9B9B9B', // Gray
  ];

  static String extractTitleFromNotionFilename(String filename) {
    var name = filename;
    if (name.contains('/') || name.contains(r'\')) {
      name = name.split(RegExp(r'[/\\]')).last;
    }
    if (name.toLowerCase().endsWith('.csv')) {
      name = name.substring(0, name.length - 4);
    }
    if (name.endsWith('_all')) {
      name = name.substring(0, name.length - 4);
    }
    name = name.replaceAll(RegExp(r'[\s_]+[a-f0-9]{32}$', caseSensitive: false), '');
    name = name.trim();
    return name.isNotEmpty ? name : 'Imported Database';
  }

  static List<List<String>> parseCsv(String input) {
    var clean = input;
    if (clean.startsWith('\uFEFF')) {
      clean = clean.substring(1);
    }

    final firstLine = clean.split(RegExp(r'\r?\n')).firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    );
    String delimiter = ',';
    if (firstLine.contains(';') && !firstLine.contains(',')) {
      delimiter = ';';
    } else if (firstLine.contains('\t') && !firstLine.contains(',')) {
      delimiter = '\t';
    }

    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    bool inQuotes = false;
    int i = 0;

    while (i < clean.length) {
      final char = clean[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < clean.length && clean[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          inQuotes = true;
          i++;
          continue;
        } else if (char == delimiter) {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < clean.length && clean[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(List.from(currentRow));
      }
    }

    return rows;
  }

  static String? tryParseDate(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    final dmyMatch = RegExp(r'^(\d{1,2})[/\.](\d{1,2})[/\.](\d{4})$').firstMatch(clean);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    final ymdMatch = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(clean);
    if (ymdMatch != null) {
      final y = int.parse(ymdMatch.group(1)!);
      final m = int.parse(ymdMatch.group(2)!);
      final d = int.parse(ymdMatch.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }

    final parsed = DateTime.tryParse(clean);
    if (parsed != null) {
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  ParsedCsvDatabase parseNotionCsv(String csvContent, {String? filename}) {
    final title = filename != null
        ? extractTitleFromNotionFilename(filename)
        : 'Imported Database';

    final allRows = parseCsv(csvContent);
    if (allRows.isEmpty) {
      throw const FormatException('CSV content is empty');
    }

    final headers = allRows.first;
    final dataRows = allRows.skip(1).toList();

    // Find title column index
    int titleColIdx = 0;
    final titlePattern = RegExp(
      r'^(name|title|описание|название|наименование|задача|item|page)$',
      caseSensitive: false,
    );
    for (int i = 0; i < headers.length; i++) {
      if (titlePattern.hasMatch(headers[i].trim())) {
        titleColIdx = i;
        break;
      }
    }

    // Infer column types
    final columns = <NotionCsvColumnInfo>[];
    for (int colIdx = 0; colIdx < headers.length; colIdx++) {
      final colName = headers[colIdx].trim();
      final values = dataRows.map((r) => colIdx < r.length ? r[colIdx] : '').toList();

      if (colIdx == titleColIdx) {
        columns.add(NotionCsvColumnInfo(
          name: colName,
          type: 'title',
          distinctValues: values.toSet().toList(),
        ));
      } else {
        final nonNull = values.where((v) => v.trim().isNotEmpty).toList();
        if (nonNull.isEmpty) {
          columns.add(NotionCsvColumnInfo(
            name: colName,
            type: 'text',
            distinctValues: const [],
          ));
          continue;
        }

        // Checkbox
        final isBool = nonNull.every((v) {
          final l = v.trim().toLowerCase();
          return l == 'true' || l == 'false' || l == 'yes' || l == 'no' || l == '1' || l == '0';
        });
        if (isBool) {
          columns.add(NotionCsvColumnInfo(
            name: colName,
            type: 'checkbox',
            distinctValues: nonNull.toSet().toList(),
          ));
          continue;
        }

        // URL
        final isUrl = nonNull.every((v) {
          final l = v.trim().toLowerCase();
          return l.startsWith('http://') ||
              l.startsWith('https://') ||
              l.startsWith('www.') ||
              (l.contains('.') &&
                  !l.contains(' ') &&
                  (l.endsWith('.com') ||
                      l.endsWith('.org') ||
                      l.endsWith('.net') ||
                      l.endsWith('.io') ||
                      l.endsWith('.dev') ||
                      l.endsWith('.app') ||
                      l.endsWith('.ru')));
        });
        if (isUrl) {
          columns.add(NotionCsvColumnInfo(
            name: colName,
            type: 'url',
            distinctValues: nonNull.toSet().toList(),
          ));
          continue;
        }

        // Date
        final isDate = nonNull.every((v) => tryParseDate(v) != null);
        if (isDate) {
          columns.add(NotionCsvColumnInfo(
            name: colName,
            type: 'date',
            distinctValues: nonNull.toSet().toList(),
          ));
          continue;
        }

        // Number
        final isNumber = nonNull.every((v) => num.tryParse(v.trim()) != null);
        if (isNumber) {
          columns.add(NotionCsvColumnInfo(
            name: colName,
            type: 'number',
            distinctValues: nonNull.toSet().toList(),
          ));
          continue;
        }

        // Select vs Text
        final distinct = nonNull.toSet().toList();
        final lowerName = colName.toLowerCase();

        final isExplicitText = lowerName == 'text' ||
            lowerName == 'текст' ||
            lowerName.contains('описание') ||
            lowerName.contains('коммент') ||
            lowerName.contains('comment') ||
            lowerName.contains('note');

        final isExplicitSelect = lowerName.contains('select') ||
            lowerName.contains('tag') ||
            lowerName.contains('статус') ||
            lowerName.contains('status') ||
            lowerName.contains('тег') ||
            lowerName.contains('категори') ||
            lowerName.contains('category') ||
            lowerName.contains('тип') ||
            lowerName.contains('type');

        final isCategorical = !isExplicitText &&
            (isExplicitSelect ||
                (nonNull.length >= 4 &&
                    distinct.length <= 15 &&
                    distinct.length <= nonNull.length * 0.6 &&
                    distinct.every((s) => s.length <= 35)));

        if (isCategorical) {
          columns.add(NotionCsvColumnInfo(
            name: colName,
            type: 'select',
            distinctValues: distinct,
          ));
          continue;
        }

        columns.add(NotionCsvColumnInfo(
          name: colName,
          type: 'text',
          distinctValues: distinct,
        ));
      }
    }

    return ParsedCsvDatabase(
      title: title,
      headers: headers,
      rows: dataRows,
      titleColumnIndex: titleColIdx,
      columns: columns,
    );
  }

  /// Imports a Notion CSV file into a brand-new page with a native database table.
  Future<String> importNotionCsvAsDatabasePage(
    String csvContent, {
    String? filename,
    String? parentPageId,
  }) async {
    final parsed = parseNotionCsv(csvContent, filename: filename);
    return importParsedCsvDatabaseAsPage(parsed, parentPageId: parentPageId);
  }

  /// Imports a pre-configured [ParsedCsvDatabase] as a new page with a database table.
  Future<String> importParsedCsvDatabaseAsPage(
    ParsedCsvDatabase parsed, {
    String? parentPageId,
  }) async {
    // 1. Create page
    final pageId = await repository.createPage(
      title: parsed.title,
      icon: '📊',
      parentId: parentPageId,
    );

    // 2. Create database
    final initialColumns = <({String name, String type, String? options, double width})>[];
    final selectOptionsMap = <int, Map<String, String>>{}; // colIdx -> {label: optId}

    for (int i = 0; i < parsed.columns.length; i++) {
      final col = parsed.columns[i];
      String? optionsJson;
      double width = 160.0;

      if (col.type == 'title') {
        width = 220.0;
      } else if (col.type == 'number') {
        width = 120.0;
      } else if (col.type == 'date') {
        width = 130.0;
      } else if (col.type == 'checkbox') {
        width = 100.0;
      } else if (col.type == 'url') {
        width = 200.0;
      } else if (col.type == 'select' || col.type == 'status') {
        width = 170.0;
        final opts = <Map<String, String>>[];
        final mapping = <String, String>{};
        for (int optIdx = 0; optIdx < col.distinctValues.length; optIdx++) {
          final label = col.distinctValues[optIdx];
          final optId = 'opt_$optIdx';
          final color = notionTagColors[optIdx % notionTagColors.length];
          opts.add({'id': optId, 'label': label, 'color': color});
          mapping[label] = optId;
        }
        optionsJson = jsonEncode(opts);
        selectOptionsMap[i] = mapping;
      } else if (col.type == 'multi_select') {
        width = 180.0;
        final opts = <Map<String, String>>[];
        final mapping = <String, String>{};
        final seenTags = <String>{};
        for (final multiVal in col.distinctValues) {
          final parts = multiVal
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          for (final label in parts) {
            if (seenTags.add(label)) {
              final optId = 'opt_${opts.length}';
              final color =
                  notionTagColors[opts.length % notionTagColors.length];
              opts.add({'id': optId, 'label': label, 'color': color});
              mapping[label] = optId;
            }
          }
        }
        optionsJson = jsonEncode(opts);
        selectOptionsMap[i] = mapping;
      }

      initialColumns.add((
        name: col.name,
        type: col.type,
        options: optionsJson,
        width: width,
      ));
    }

    final dbId = await repository.createDatabase(
      title: parsed.title,
      icon: '📊',
      parentPageId: pageId,
      initialColumns: initialColumns,
    );

    // 3. Fetch created columns to get their database IDs
    final createdCols = await repository.getColumns(dbId);

    // 4. Populate rows
    for (final row in parsed.rows) {
      final titleVal = parsed.titleColumnIndex < row.length
          ? row[parsed.titleColumnIndex]
          : '';

      final props = <String, dynamic>{};
      for (int i = 0; i < parsed.columns.length; i++) {
        if (i == parsed.titleColumnIndex) continue;
        if (i >= row.length) continue;
        final rawVal = row[i].trim();
        if (rawVal.isEmpty) continue;

        final col = parsed.columns[i];
        final dbCol = createdCols.firstWhere(
          (c) => c.name == col.name && c.type == col.type,
          orElse: () => createdCols.first,
        );

        if (col.type == 'select' || col.type == 'status') {
          final optId = selectOptionsMap[i]?[rawVal] ?? rawVal;
          props[dbCol.id] = optId;
        } else if (col.type == 'multi_select') {
          final parts = rawVal
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          final optIds =
              parts.map((l) => selectOptionsMap[i]?[l] ?? l).toList();
          props[dbCol.id] = optIds;
        } else if (col.type == 'date') {
          props[dbCol.id] = tryParseDate(rawVal) ?? rawVal;
        } else if (col.type == 'number') {
          props[dbCol.id] = num.tryParse(rawVal) ?? rawVal;
        } else if (col.type == 'checkbox') {
          final l = rawVal.toLowerCase();
          props[dbCol.id] = (l == 'true' || l == 'yes' || l == '1');
        } else {
          props[dbCol.id] = rawVal;
        }
      }

      await repository.createDatabaseRow(
        dbId,
        title: titleVal,
        properties: props,
      );
    }

    // 5. Save database node on the page
    final dbNode = databaseBlockNode(databaseId: dbId, title: parsed.title);
    await repository.savePageNodes(pageId, [dbNode]);

    return pageId;
  }

  /// Inserts a Notion CSV table as a database block into an existing page.
  Future<String> importNotionCsvIntoPage(
    String pageId,
    String csvContent, {
    String? filename,
  }) async {
    final parsed = parseNotionCsv(csvContent, filename: filename);
    return importParsedCsvDatabaseIntoPage(pageId, parsed);
  }

  /// Inserts a pre-configured [ParsedCsvDatabase] as a database block into an existing page.
  Future<String> importParsedCsvDatabaseIntoPage(
    String pageId,
    ParsedCsvDatabase parsed,
  ) async {
    // 1. Create database
    final initialColumns = <({String name, String type, String? options, double width})>[];
    final selectOptionsMap = <int, Map<String, String>>{};

    for (int i = 0; i < parsed.columns.length; i++) {
      final col = parsed.columns[i];
      String? optionsJson;
      double width = 160.0;

      if (col.type == 'title') {
        width = 220.0;
      } else if (col.type == 'number') {
        width = 120.0;
      } else if (col.type == 'date') {
        width = 130.0;
      } else if (col.type == 'checkbox') {
        width = 100.0;
      } else if (col.type == 'url') {
        width = 200.0;
      } else if (col.type == 'select' || col.type == 'status') {
        width = 170.0;
        final opts = <Map<String, String>>[];
        final mapping = <String, String>{};
        for (int optIdx = 0; optIdx < col.distinctValues.length; optIdx++) {
          final label = col.distinctValues[optIdx];
          final optId = 'opt_$optIdx';
          final color = notionTagColors[optIdx % notionTagColors.length];
          opts.add({'id': optId, 'label': label, 'color': color});
          mapping[label] = optId;
        }
        optionsJson = jsonEncode(opts);
        selectOptionsMap[i] = mapping;
      } else if (col.type == 'multi_select') {
        width = 180.0;
        final opts = <Map<String, String>>[];
        final mapping = <String, String>{};
        final seenTags = <String>{};
        for (final multiVal in col.distinctValues) {
          final parts = multiVal
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          for (final label in parts) {
            if (seenTags.add(label)) {
              final optId = 'opt_${opts.length}';
              final color =
                  notionTagColors[opts.length % notionTagColors.length];
              opts.add({'id': optId, 'label': label, 'color': color});
              mapping[label] = optId;
            }
          }
        }
        optionsJson = jsonEncode(opts);
        selectOptionsMap[i] = mapping;
      }

      initialColumns.add((
        name: col.name,
        type: col.type,
        options: optionsJson,
        width: width,
      ));
    }

    final dbId = await repository.createDatabase(
      title: parsed.title,
      icon: '📊',
      parentPageId: pageId,
      initialColumns: initialColumns,
    );

    final createdCols = await repository.getColumns(dbId);

    // Populate rows
    for (final row in parsed.rows) {
      final titleVal = parsed.titleColumnIndex < row.length
          ? row[parsed.titleColumnIndex]
          : '';

      final props = <String, dynamic>{};
      for (int i = 0; i < parsed.columns.length; i++) {
        if (i == parsed.titleColumnIndex) continue;
        if (i >= row.length) continue;
        final rawVal = row[i].trim();
        if (rawVal.isEmpty) continue;

        final col = parsed.columns[i];
        final dbCol = createdCols.firstWhere(
          (c) => c.name == col.name && c.type == col.type,
          orElse: () => createdCols.first,
        );

        if (col.type == 'select' || col.type == 'status') {
          final optId = selectOptionsMap[i]?[rawVal] ?? rawVal;
          props[dbCol.id] = optId;
        } else if (col.type == 'multi_select') {
          final parts = rawVal
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          final optIds =
              parts.map((l) => selectOptionsMap[i]?[l] ?? l).toList();
          props[dbCol.id] = optIds;
        } else if (col.type == 'date') {
          props[dbCol.id] = tryParseDate(rawVal) ?? rawVal;
        } else if (col.type == 'number') {
          props[dbCol.id] = num.tryParse(rawVal) ?? rawVal;
        } else if (col.type == 'checkbox') {
          final l = rawVal.toLowerCase();
          props[dbCol.id] = (l == 'true' || l == 'yes' || l == '1');
        } else {
          props[dbCol.id] = rawVal;
        }
      }

      await repository.createDatabaseRow(
        dbId,
        title: titleVal,
        properties: props,
      );
    }

    // Append database node to page
    final snapshot = await repository.loadPageSnapshot(pageId);
    final nodes = snapshot.document.root.children.toList();
    nodes.add(databaseBlockNode(databaseId: dbId, title: parsed.title));
    await repository.savePageNodes(
      pageId, nodes, expectedVersion: snapshot.version,
    );

    return dbId;
  }

  // ---------------------------------------------------------------------------
  // File I/O Helpers
  // ---------------------------------------------------------------------------

  /// Saves text content to the user's Downloads or Documents folder, returning the created file.
  static Future<File> saveExportToFile(
    String content,
    String defaultFilename, {
    String? customDirectoryPath,
  }) async {
    Directory? targetDir;
    if (customDirectoryPath != null) {
      targetDir = Directory(customDirectoryPath);
    } else {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
      targetDir ??= await getApplicationDocumentsDirectory();
    }

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 1. Очистка недопустимых символов: \ / : * ? " < > |
    var sanitized = defaultFilename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    // 2. Удаление концевых точек и пробелов (запрещено в Windows NTFS)
    sanitized = sanitized.replaceAll(RegExp(r'[. ]+$'), '');

    // 3. Защита от 22 зарезервированных системных имен устройств Windows
    final dotIndex = sanitized.lastIndexOf('.');
    final baseName = dotIndex != -1 ? sanitized.substring(0, dotIndex) : sanitized;
    final ext = dotIndex != -1 ? sanitized.substring(dotIndex) : '';

    const reservedDeviceNames = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };

    if (reservedDeviceNames.contains(baseName.toUpperCase())) {
      sanitized = '_$baseName$ext';
    }
    if (sanitized.isEmpty) {
      sanitized = 'untitled$ext';
    }

    // 4. Корректное объединение путей с использованием системного разделителя
    final filePath = '${targetDir.path}${Platform.pathSeparator}$sanitized';
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    return file;
  }
}
