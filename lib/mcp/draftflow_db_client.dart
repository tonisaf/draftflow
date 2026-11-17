import 'dart:convert';
import 'dart:io';

import 'package:fractional_indexing/fractional_indexing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

class DraftFlowDbClient {
  final Database db;
  final String dbPath;
  static const _uuid = Uuid();

  DraftFlowDbClient._(this.db, this.dbPath) {
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA busy_timeout = 5000;');
  }

  static DraftFlowDbClient open([String? explicitPath]) {
    final path = findDatabasePath(explicitPath);
    if (path == null) {
      throw StateError(
        'DraftFlow SQLite database not found. Specify path via --db-path or DRAFTFLOW_DB_PATH environment variable.',
      );
    }
    final database = sqlite3.open(path);
    return DraftFlowDbClient._(database, path);
  }

  void close() {
    db.dispose();
  }

  static String? findDatabasePath([String? explicit]) {
    if (explicit != null && explicit.trim().isNotEmpty) {
      final f = File(explicit.trim());
      if (f.existsSync()) return f.path;
    }

    final envPath = Platform.environment['DRAFTFLOW_DB_PATH'];
    if (envPath != null && envPath.trim().isNotEmpty) {
      final f = File(envPath.trim());
      if (f.existsSync()) return f.path;
    }

    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    final candidateDirs = <String>[];

    if (Platform.isMacOS) {
      candidateDirs.addAll([
        '$home/Library/Containers/com.draftflow.app/Data/Documents',
        '$home/Library/Containers/com.noteshere.notesHere/Data/Documents',
        '$home/Library/Application Support/com.draftflow.app',
        '$home/Library/Application Support/notes_here',
        '$home/Documents',
      ]);
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '';
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      candidateDirs.addAll([
        '$appData\\com.draftflow.app',
        '$appData\\notes_here',
        '$localAppData\\com.draftflow.app',
        '$home\\Documents',
      ]);
    } else {
      candidateDirs.addAll([
        '$home/.local/share/com.draftflow.app',
        '$home/.local/share/notes_here',
        '$home/Documents',
      ]);
    }

    final foundFiles = <File>[];
    for (final dirPath in candidateDirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        try {
          for (final entity in dir.listSync()) {
            if (entity is File && entity.path.endsWith('.sqlite')) {
              final name = entity.uri.pathSegments.last;
              if (name.startsWith('notes_here_')) {
                foundFiles.add(entity);
              }
            }
          }
        } catch (_) {}
      }
    }

    if (foundFiles.isEmpty) return null;

    // Prefer account databases first (e.g. notes_here_account_*.sqlite), then sort by last modified descending
    foundFiles.sort((a, b) {
      final aIsAccount = a.path.contains('notes_here_account_');
      final bIsAccount = b.path.contains('notes_here_account_');
      if (aIsAccount && !bIsAccount) return -1;
      if (!aIsAccount && bIsAccount) return 1;
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    });

    return foundFiles.first.path;
  }

  // =========================================================================
  // Pages & Notes
  // =========================================================================

  List<Map<String, dynamic>> searchNotes(String query, {int limit = 10}) {
    final clean = '%${query.trim().toLowerCase()}%';
    final results = db.select(
      '''
      SELECT p.id, p.title, p.icon, p.parent_id, p.created_at, b.type, b.content
      FROM pages p
      LEFT JOIN blocks b ON b.page_id = p.id AND b.trashed_at IS NULL
      WHERE p.trashed_at IS NULL AND p.database_id IS NULL
        AND (
          (p.title_folded IS NOT NULL AND p.title_folded LIKE ?)
          OR LOWER(p.title) LIKE ?
          OR LOWER(b.content) LIKE ?
        )
      GROUP BY p.id
      ORDER BY p.created_at DESC
      LIMIT ?
      ''',
      [clean, clean, clean, limit],
    );

    return results.map((row) {
      final rawContent = row['content'] as String?;
      String snippet = '';
      if (rawContent != null && rawContent.isNotEmpty) {
        snippet = _extractTextFromBlockJson(rawContent);
      }
      return {
        'id': row['id'],
        'title': (row['title'] as String?)?.isNotEmpty == true ? row['title'] : 'Untitled',
        'icon': row['icon'],
        'parentId': row['parent_id'],
        'createdAt': row['created_at'],
        'snippet': snippet,
      };
    }).toList();
  }

  List<Map<String, dynamic>> listPages({String? parentId}) {
    final ResultSet results;
    if (parentId != null) {
      results = db.select(
        '''
        SELECT id, title, icon, parent_id, created_at, order_key
        FROM pages
        WHERE database_id IS NULL AND trashed_at IS NULL AND parent_id = ?
        ORDER BY order_key, created_at
        ''',
        [parentId],
      );
    } else {
      results = db.select(
        '''
        SELECT id, title, icon, parent_id, created_at, order_key
        FROM pages
        WHERE database_id IS NULL AND trashed_at IS NULL AND parent_id IS NULL
        ORDER BY order_key, created_at
        ''',
      );
    }

    return results.map((row) => {
      'id': row['id'],
      'title': (row['title'] as String?)?.isNotEmpty == true ? row['title'] : 'Untitled',
      'icon': row['icon'],
      'parentId': row['parent_id'],
      'createdAt': row['created_at'],
    }).toList();
  }

  Map<String, dynamic>? getPage(String pageIdOrTitle) {
    var pageRes = db.select(
      'SELECT id, title, icon, cover, parent_id, database_id, created_at FROM pages WHERE id = ? AND trashed_at IS NULL',
      [pageIdOrTitle],
    );
    if (pageRes.isEmpty) {
      final folded = pageIdOrTitle.trim().toLowerCase();
      pageRes = db.select(
        '''
        SELECT id, title, icon, cover, parent_id, database_id, created_at
        FROM pages
        WHERE (title = ? OR title_folded = ?) AND trashed_at IS NULL
        ORDER BY created_at DESC
        LIMIT 1
        ''',
        [pageIdOrTitle.trim(), folded],
      );
    }
    if (pageRes.isEmpty) return null;

    final pageRow = pageRes.first;
    final realPageId = pageRow['id'] as String;
    final blockRows = db.select(
      'SELECT id, type, content, order_key FROM blocks WHERE page_id = ? AND trashed_at IS NULL ORDER BY order_key',
      [realPageId],
    );

    final sb = StringBuffer();
    final blocksList = <Map<String, dynamic>>[];

    for (final b in blockRows) {
      final type = b['type'] as String;
      final rawJson = b['content'] as String;
      blocksList.add({
        'id': b['id'],
        'type': type,
        'orderKey': b['order_key'],
      });
      final md = _blockJsonToMarkdown(type, rawJson);
      if (md.isNotEmpty) {
        sb.writeln(md);
      }
    }

    return {
      'id': pageRow['id'],
      'title': (pageRow['title'] as String?)?.isNotEmpty == true ? pageRow['title'] : 'Untitled',
      'icon': pageRow['icon'],
      'cover': pageRow['cover'],
      'parentId': pageRow['parent_id'],
      'databaseId': pageRow['database_id'],
      'createdAt': pageRow['created_at'],
      'markdown': sb.toString().trim(),
      'blocksCount': blockRows.length,
    };
  }

  Map<String, dynamic> createPage({
    required String title,
    String? parentId,
    String? content,
    String? icon,
  }) {
    final pageId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final pageKey = FractionalIndexer.generateKeyBetween(null, null)!;

    db.execute(
      '''
      INSERT INTO pages (id, title, parent_id, icon, order_key, title_folded, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [pageId, title, parentId, icon, pageKey, title.toLowerCase(), now],
    );

    final markdown = content?.trim() ?? '';
    final blocks = _markdownToBlockEntries(markdown);

    if (blocks.isEmpty) {
      final blockId = _uuid.v4();
      final blockKey = FractionalIndexer.generateKeyBetween(null, null)!;
      final emptyParagraphJson = jsonEncode({
        'type': 'paragraph',
        'data': {'delta': []},
      });
      db.execute(
        '''
        INSERT INTO blocks (id, page_id, type, content, order_key)
        VALUES (?, ?, 'paragraph', ?, ?)
        ''',
        [blockId, pageId, emptyParagraphJson, blockKey],
      );
    } else {
      String? prevKey;
      for (final b in blocks) {
        final blockId = _uuid.v4();
        final key = FractionalIndexer.generateKeyBetween(prevKey, null)!;
        prevKey = key;
        db.execute(
          '''
          INSERT INTO blocks (id, page_id, type, content, order_key)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [blockId, pageId, b.type, jsonEncode(b.jsonMap), key],
        );
      }
    }

    return {
      'success': true,
      'pageId': pageId,
      'title': title,
    };
  }

  Map<String, dynamic> updatePage(
    String pageId, {
    String? title,
    String? content,
    bool append = false,
  }) {
    final exists = db.select('SELECT id, title FROM pages WHERE id = ? AND trashed_at IS NULL', [pageId]);
    if (exists.isEmpty) {
      throw ArgumentError('Page with id $pageId not found');
    }

    if (title != null) {
      db.execute(
        'UPDATE pages SET title = ?, title_folded = ? WHERE id = ?',
        [title, title.toLowerCase(), pageId],
      );
    }

    if (content != null) {
      final blocks = _markdownToBlockEntries(content);
      if (!append) {
        db.execute('DELETE FROM blocks WHERE page_id = ?', [pageId]);
      }

      String? lastKey;
      if (append) {
        final lastKeyRes = db.select(
          'SELECT order_key FROM blocks WHERE page_id = ? ORDER BY order_key DESC LIMIT 1',
          [pageId],
        );
        if (lastKeyRes.isNotEmpty) {
          lastKey = lastKeyRes.first['order_key'] as String;
        }
      }

      for (final b in blocks) {
        final blockId = _uuid.v4();
        final key = FractionalIndexer.generateKeyBetween(lastKey, null)!;
        lastKey = key;
        db.execute(
          '''
          INSERT INTO blocks (id, page_id, type, content, order_key)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [blockId, pageId, b.type, jsonEncode(b.jsonMap), key],
        );
      }
    }

    return {'success': true, 'pageId': pageId};
  }

  Map<String, dynamic> deletePage(String pageId) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    db.execute('UPDATE pages SET trashed_at = ? WHERE id = ?', [now, pageId]);
    db.execute('UPDATE blocks SET trashed_at = ? WHERE page_id = ?', [now, pageId]);
    return {'success': true, 'pageId': pageId};
  }

  // =========================================================================
  // Notion-like Relational Databases
  // =========================================================================

  List<Map<String, dynamic>> listDatabases() {
    final dbs = db.select(
      'SELECT id, title, icon, parent_page_id, created_at FROM databases WHERE trashed_at IS NULL ORDER BY created_at',
    );

    final result = <Map<String, dynamic>>[];
    for (final d in dbs) {
      final dbId = d['id'] as String;
      final cols = db.select(
        'SELECT id, name, type, options, order_key FROM database_columns WHERE database_id = ? ORDER BY order_key',
        [dbId],
      );

      final countRes = db.select(
        'SELECT COUNT(*) as count FROM pages WHERE database_id = ? AND trashed_at IS NULL',
        [dbId],
      );
      final rowCount = countRes.first['count'] as int;

      result.add({
        'id': dbId,
        'title': (d['title'] as String?)?.isNotEmpty == true ? d['title'] : 'Untitled Database',
        'icon': d['icon'],
        'parentPageId': d['parent_page_id'],
        'createdAt': d['created_at'],
        'rowCount': rowCount,
        'columns': cols.map((c) {
          Map<String, dynamic>? optionsMap;
          final optStr = c['options'] as String?;
          if (optStr != null && optStr.isNotEmpty) {
            try {
              optionsMap = jsonDecode(optStr) as Map<String, dynamic>;
            } catch (_) {}
          }
          return {
            'id': c['id'],
            'name': c['name'],
            'type': c['type'],
            'options': optionsMap,
          };
        }).toList(),
      });
    }

    return result;
  }

  List<Map<String, dynamic>> queryDatabaseRows(
    String databaseId, {
    String? search,
    int limit = 50,
  }) {
    // 1. Get column map (id -> name)
    final cols = db.select(
      'SELECT id, name, type FROM database_columns WHERE database_id = ? ORDER BY order_key',
      [databaseId],
    );
    final colMap = {for (final c in cols) c['id'] as String: c['name'] as String};

    // 2. Query rows
    final ResultSet rows;
    if (search != null && search.trim().isNotEmpty) {
      final clean = '%${search.trim().toLowerCase()}%';
      rows = db.select(
        '''
        SELECT id, title, properties, created_at, order_key
        FROM pages
        WHERE database_id = ? AND trashed_at IS NULL
          AND (
            (title_folded IS NOT NULL AND title_folded LIKE ?)
            OR (properties_folded IS NOT NULL AND properties_folded LIKE ?)
            OR LOWER(title) LIKE ?
            OR LOWER(properties) LIKE ?
          )
        ORDER BY order_key, created_at DESC
        LIMIT ?
        ''',
        [databaseId, clean, clean, clean, clean, limit],
      );
    } else {
      rows = db.select(
        '''
        SELECT id, title, properties, created_at, order_key
        FROM pages
        WHERE database_id = ? AND trashed_at IS NULL
        ORDER BY order_key, created_at DESC
        LIMIT ?
        ''',
        [databaseId, limit],
      );
    }

    return rows.map((r) {
      final rawProps = r['properties'] as String?;
      final props = <String, dynamic>{};
      if (rawProps != null && rawProps.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawProps) as Map<String, dynamic>;
          for (final entry in decoded.entries) {
            final colName = colMap[entry.key] ?? entry.key;
            props[colName] = entry.value;
          }
        } catch (_) {}
      }

      return {
        'id': r['id'],
        'title': r['title'] ?? '',
        'properties': props,
        'createdAt': r['created_at'],
      };
    }).toList();
  }

  Map<String, dynamic> createDatabaseRow(
    String databaseId, {
    required String title,
    Map<String, dynamic>? properties,
  }) {
    final rowId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Map column names to IDs if needed
    final cols = db.select('SELECT id, name FROM database_columns WHERE database_id = ?', [databaseId]);
    final nameToId = {for (final c in cols) (c['name'] as String).toLowerCase(): c['id'] as String};

    final mappedProps = <String, dynamic>{};
    if (properties != null) {
      for (final entry in properties.entries) {
        final colId = nameToId[entry.key.toLowerCase()] ?? entry.key;
        mappedProps[colId] = entry.value;
      }
    }

    final keyRes = db.select(
      'SELECT order_key FROM pages WHERE database_id = ? ORDER BY order_key DESC LIMIT 1',
      [databaseId],
    );
    final lastKey = keyRes.isNotEmpty ? keyRes.first['order_key'] as String? : null;
    final rowKey = FractionalIndexer.generateKeyBetween(lastKey, null)!;

    final propsJson = jsonEncode(mappedProps);
    db.execute(
      '''
      INSERT INTO pages (id, title, database_id, properties, order_key, title_folded, properties_folded, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [rowId, title, databaseId, propsJson, rowKey, title.toLowerCase(), propsJson.toLowerCase(), now],
    );

    // Initial paragraph block
    final blockId = _uuid.v4();
    final blockKey = FractionalIndexer.generateKeyBetween(null, null)!;
    final initialJson = jsonEncode({
      'type': 'paragraph',
      'data': {'delta': []},
    });
    db.execute(
      '''
      INSERT INTO blocks (id, page_id, type, content, order_key)
      VALUES (?, ?, 'paragraph', ?, ?)
      ''',
      [blockId, rowId, initialJson, blockKey],
    );

    return {'success': true, 'rowId': rowId, 'title': title};
  }

  Map<String, dynamic> updateDatabaseRow(
    String rowId, {
    String? title,
    Map<String, dynamic>? properties,
  }) {
    final rowRes = db.select(
      'SELECT id, title, database_id, properties FROM pages WHERE id = ? AND database_id IS NOT NULL AND trashed_at IS NULL',
      [rowId],
    );
    if (rowRes.isEmpty) {
      throw ArgumentError('Database row with id $rowId not found');
    }

    final row = rowRes.first;
    final dbId = row['database_id'] as String;

    final cols = db.select('SELECT id, name FROM database_columns WHERE database_id = ?', [dbId]);
    final nameToId = {for (final c in cols) (c['name'] as String).toLowerCase(): c['id'] as String};

    var currentProps = <String, dynamic>{};
    final rawProps = row['properties'] as String?;
    if (rawProps != null && rawProps.isNotEmpty) {
      try {
        currentProps = jsonDecode(rawProps) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (properties != null) {
      for (final entry in properties.entries) {
        final colId = nameToId[entry.key.toLowerCase()] ?? entry.key;
        currentProps[colId] = entry.value;
      }
    }

    final newTitle = title ?? row['title'] as String;
    final newPropsJson = jsonEncode(currentProps);

    db.execute(
      '''
      UPDATE pages
      SET title = ?, properties = ?, title_folded = ?, properties_folded = ?
      WHERE id = ?
      ''',
      [newTitle, newPropsJson, newTitle.toLowerCase(), newPropsJson.toLowerCase(), rowId],
    );

    return {'success': true, 'rowId': rowId};
  }

  Map<String, dynamic> deleteDatabaseRow(String rowId) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    db.execute(
      'UPDATE pages SET trashed_at = ? WHERE id = ? AND database_id IS NOT NULL',
      [now, rowId],
    );
    return {'success': true, 'rowId': rowId};
  }

  // =========================================================================
  // Block <-> Markdown serialization helpers
  // =========================================================================

  static String _extractTextFromBlockJson(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>?;
      final delta = data?['delta'] as List<dynamic>?;
      if (delta != null) {
        final sb = StringBuffer();
        for (final op in delta) {
          if (op is Map && op['insert'] is String) {
            sb.write(op['insert']);
          }
        }
        return sb.toString().trim();
      }
    } catch (_) {}
    return '';
  }

  static String _blockJsonToMarkdown(String type, String rawJson) {
    final text = _extractTextFromBlockJson(rawJson);
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'heading':
          final level = (data['level'] as num?)?.toInt() ?? 1;
          final hashes = '#' * level;
          return '$hashes $text\n';
        case 'bulleted_list':
          return '- $text';
        case 'numbered_list':
          return '1. $text';
        case 'todo_list':
          final checked = data['checked'] == true;
          return checked ? '- [x] $text' : '- [ ] $text';
        case 'quote':
          return '> $text';
        case 'code':
          final lang = data['language'] as String? ?? '';
          return '```$lang\n$text\n```\n';
        case 'divider':
          return '---\n';
        case 'paragraph':
        default:
          return text.isEmpty ? '' : '$text\n';
      }
    } catch (_) {
      return text;
    }
  }

  static List<_BlockEntry> _markdownToBlockEntries(String markdown) {
    final lines = LineSplitter.split(markdown).toList();
    final entries = <_BlockEntry>[];

    var inCodeBlock = false;
    var codeLang = '';
    final codeLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().startsWith('```')) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          codeLang = line.trim().substring(3).trim();
          codeLines.clear();
        } else {
          inCodeBlock = false;
          entries.add(_BlockEntry(
            type: 'code',
            jsonMap: {
              'type': 'code',
              'data': {
                'language': codeLang,
                'delta': [{'insert': codeLines.join('\n')}],
              },
            },
          ));
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('# ')) {
        entries.add(_BlockEntry(
          type: 'heading',
          jsonMap: {
            'type': 'heading',
            'data': {'level': 1, 'delta': [{'insert': trimmed.substring(2)}]},
          },
        ));
      } else if (trimmed.startsWith('## ')) {
        entries.add(_BlockEntry(
          type: 'heading',
          jsonMap: {
            'type': 'heading',
            'data': {'level': 2, 'delta': [{'insert': trimmed.substring(3)}]},
          },
        ));
      } else if (trimmed.startsWith('### ')) {
        entries.add(_BlockEntry(
          type: 'heading',
          jsonMap: {
            'type': 'heading',
            'data': {'level': 3, 'delta': [{'insert': trimmed.substring(4)}]},
          },
        ));
      } else if (trimmed.startsWith('- [ ] ')) {
        entries.add(_BlockEntry(
          type: 'todo_list',
          jsonMap: {
            'type': 'todo_list',
            'data': {'checked': false, 'delta': [{'insert': trimmed.substring(6)}]},
          },
        ));
      } else if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
        entries.add(_BlockEntry(
          type: 'todo_list',
          jsonMap: {
            'type': 'todo_list',
            'data': {'checked': true, 'delta': [{'insert': trimmed.substring(6)}]},
          },
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        entries.add(_BlockEntry(
          type: 'bulleted_list',
          jsonMap: {
            'type': 'bulleted_list',
            'data': {'delta': [{'insert': trimmed.substring(2)}]},
          },
        ));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        final content = trimmed.replaceFirst(RegExp(r'^\d+\.\s+'), '');
        entries.add(_BlockEntry(
          type: 'numbered_list',
          jsonMap: {
            'type': 'numbered_list',
            'data': {'delta': [{'insert': content}]},
          },
        ));
      } else if (trimmed.startsWith('> ')) {
        entries.add(_BlockEntry(
          type: 'quote',
          jsonMap: {
            'type': 'quote',
            'data': {'delta': [{'insert': trimmed.substring(2)}]},
          },
        ));
      } else if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        entries.add(_BlockEntry(
          type: 'divider',
          jsonMap: {'type': 'divider', 'data': {}},
        ));
      } else {
        entries.add(_BlockEntry(
          type: 'paragraph',
          jsonMap: {
            'type': 'paragraph',
            'data': {'delta': [{'insert': trimmed}]},
          },
        ));
      }
    }

    if (inCodeBlock && codeLines.isNotEmpty) {
      entries.add(_BlockEntry(
        type: 'code',
        jsonMap: {
          'type': 'code',
          'data': {
            'language': codeLang,
            'delta': [{'insert': codeLines.join('\n')}],
          },
        },
      ));
    }

    return entries;
  }
}

class _BlockEntry {
  final String type;
  final Map<String, dynamic> jsonMap;
  _BlockEntry({required this.type, required this.jsonMap});
}
