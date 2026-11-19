import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'draftflow_db_client.dart';

class DraftFlowMcpServer {
  final DraftFlowDbClient client;
  final Stream<String> _inputLines;
  final void Function(String) _outputSink;
  final FutureOr<void> Function()? onDataMutated;

  DraftFlowMcpServer({
    required this.client,
    Stream<String>? inputLines,
    void Function(String)? outputSink,
    this.onDataMutated,
  })  : _inputLines = inputLines ??
            stdin
                .transform(utf8.decoder)
                .transform(const LineSplitter()),
        _outputSink = outputSink ?? ((line) => stdout.writeln(line));

  static Future<DraftFlowMcpServer> create([String? dbPath]) async {
    final client = DraftFlowDbClient.open(dbPath);
    return DraftFlowMcpServer(client: client);
  }

  Future<void> start() async {
    await for (final line in _inputLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final request = jsonDecode(trimmed) as Map<String, dynamic>;
        final response = await handleMessage(request);
        if (response != null) {
          _outputSink(jsonEncode(response));
        }
      } catch (e) {
        _outputSink(jsonEncode({
          'jsonrpc': '2.0',
          'id': null,
          'error': {'code': -32700, 'message': 'Parse error: $e'},
        }));
      }
    }
  }

  Future<Map<String, dynamic>?> handleMessage(Map<String, dynamic> msg) async {
    final method = msg['method'] as String?;
    final id = msg['id'];
    final rawParams = msg['params'];
    final params = rawParams is Map ? rawParams.cast<String, dynamic>() : <String, dynamic>{};

    // Notifications (no id)
    if (id == null) {
      if (method == 'notifications/initialized') {
        // Client confirmed ready
      }
      return null;
    }

    try {
      switch (method) {
        case 'initialize':
          return _wrapSuccess(id, {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'tools': {'listChanged': false},
              'resources': {'listChanged': false},
            },
            'serverInfo': {
              'name': 'draftflow',
              'version': '1.0.18',
            },
            'instructions':
                'DraftFlow is a minimalist notes and Notion-like relational database workspace. '
                'Use the provided tools to search, read, create, and modify user notes and databases.',
          });

        case 'ping':
          return _wrapSuccess(id, {});

        case 'tools/list':
          return _wrapSuccess(id, {'tools': _toolDefinitions});

        case 'tools/call':
          final toolName = params['name'] as String?;
          final rawArgs = params['arguments'];
          final args = rawArgs is Map ? rawArgs.cast<String, dynamic>() : <String, dynamic>{};
          final toolResult = await _executeTool(toolName, args);
          return _wrapSuccess(id, toolResult);

        case 'resources/list':
          final pages = client.listPages();
          final resources = pages.map((p) => {
            'uri': 'draftflow://pages/${p['id']}',
            'name': p['title'],
            'description': 'Note page in DraftFlow (created: ${p['createdAt']})',
            'mimeType': 'text/markdown',
          }).toList();
          return _wrapSuccess(id, {'resources': resources});

        case 'resources/read':
          final uri = params['uri'] as String? ?? '';
          final pageId = uri.replaceFirst('draftflow://pages/', '');
          final page = client.getPage(pageId);
          if (page == null) {
            return _wrapError(id, -32602, 'Resource not found: $uri');
          }
          return _wrapSuccess(id, {
            'contents': [
              {
                'uri': uri,
                'mimeType': 'text/markdown',
                'text': '# ${page['title']}\n\n${page['markdown']}',
              }
            ]
          });

        default:
          return _wrapError(id, -32601, 'Method not found: $method');
      }
    } catch (e, st) {
      return _wrapError(id, -32603, 'Internal error: $e\n$st');
    }
  }

  Future<Map<String, dynamic>> _executeTool(String? name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'search_notes':
          final query = args['query']?.toString() ?? '';
          final limit = (args['limit'] as num?)?.toInt() ?? 10;
          final notes = client.searchNotes(query, limit: limit);
          return _mcpTextResult(jsonEncode(notes));

        case 'list_pages':
          final parentId = args['parentId']?.toString();
          final pages = client.listPages(parentId: parentId);
          return _mcpTextResult(jsonEncode(pages));

        case 'get_page':
          final pageId = args['pageId']?.toString() ?? '';
          if (pageId.isEmpty) throw ArgumentError('pageId is required');
          final page = client.getPage(pageId);
          if (page == null) {
            return _mcpErrorResult('Page with id "$pageId" not found');
          }
          final formatted = '''# ${page['title']}
Page ID: ${page['id']}
Created: ${page['createdAt']}

${page['markdown']}
''';
          return _mcpTextResult(formatted);

        case 'create_page':
          final title = args['title']?.toString() ?? 'Untitled';
          final content = args['content']?.toString();
          final parentId = args['parentId']?.toString();
          final icon = args['icon']?.toString();
          final res = client.createPage(
            title: title,
            content: content,
            parentId: parentId,
            icon: icon,
          );
          await onDataMutated?.call();
          return _mcpTextResult(
            'Created page "${res['title']}" with ID: ${res['pageId']}',
          );

        case 'update_page':
          final pageId = args['pageId']?.toString() ?? '';
          if (pageId.isEmpty) throw ArgumentError('pageId is required');
          final title = args['title']?.toString();
          final content = args['content']?.toString();
          final append = args['append'] == true;
          client.updatePage(
            pageId,
            title: title,
            content: content,
            append: append,
          );
          await onDataMutated?.call();
          return _mcpTextResult('Updated page $pageId successfully');

        case 'delete_page':
          final pageId = args['pageId']?.toString() ?? '';
          if (pageId.isEmpty) throw ArgumentError('pageId is required');
          client.deletePage(pageId);
          await onDataMutated?.call();
          return _mcpTextResult('Moved page $pageId to trash');

        case 'list_databases':
          final dbs = client.listDatabases();
          return _mcpTextResult(jsonEncode(dbs));

        case 'query_database_rows':
          final dbId = args['databaseId']?.toString() ?? '';
          if (dbId.isEmpty) throw ArgumentError('databaseId is required');
          final search = args['search']?.toString();
          final limit = (args['limit'] as num?)?.toInt() ?? 50;
          final rows = client.queryDatabaseRows(dbId, search: search, limit: limit);
          return _mcpTextResult(jsonEncode(rows));

        case 'create_database_row':
          final dbId = args['databaseId']?.toString() ?? '';
          final title = args['title']?.toString() ?? 'Untitled';
          final props = args['properties'] is Map<String, dynamic>
              ? args['properties'] as Map<String, dynamic>
              : null;
          if (dbId.isEmpty) throw ArgumentError('databaseId is required');
          final res = client.createDatabaseRow(dbId, title: title, properties: props);
          await onDataMutated?.call();
          return _mcpTextResult('Created row "${res['title']}" with ID: ${res['rowId']}');

        case 'update_database_row':
          final rowId = args['rowId']?.toString() ?? '';
          final title = args['title']?.toString();
          final props = args['properties'] is Map<String, dynamic>
              ? args['properties'] as Map<String, dynamic>
              : null;
          if (rowId.isEmpty) throw ArgumentError('rowId is required');
          client.updateDatabaseRow(rowId, title: title, properties: props);
          await onDataMutated?.call();
          return _mcpTextResult('Updated database row $rowId');

        case 'delete_database_row':
          final rowId = args['rowId']?.toString() ?? '';
          if (rowId.isEmpty) throw ArgumentError('rowId is required');
          client.deleteDatabaseRow(rowId);
          await onDataMutated?.call();
          return _mcpTextResult('Deleted database row $rowId');

        default:
          return _mcpErrorResult('Unknown tool: $name');
      }
    } catch (e) {
      return _mcpErrorResult('Tool execution failed: $e');
    }
  }

  Map<String, dynamic> _mcpTextResult(String text) => {
        'content': [
          {'type': 'text', 'text': text}
        ]
      };

  Map<String, dynamic> _mcpErrorResult(String error) => {
        'isError': true,
        'content': [
          {'type': 'text', 'text': error}
        ]
      };

  Map<String, dynamic> _wrapSuccess(dynamic id, Map<String, dynamic> result) => {
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      };

  Map<String, dynamic> _wrapError(dynamic id, int code, String message) => {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': code, 'message': message},
      };

  static final List<Map<String, dynamic>> _toolDefinitions = [
    {
      'name': 'search_notes',
      'description': 'Search pages and notes by keyword or full text across titles and blocks in DraftFlow',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Keyword or phrase to search for',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of results to return (default: 10)',
          },
        },
        'required': ['query'],
      },
    },
    {
      'name': 'list_pages',
      'description': 'List note pages with hierarchy (parent/child) and creation timestamps in DraftFlow',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'parentId': {
            'type': 'string',
            'description': 'Optional parent page UUID to filter subpages',
          },
        },
      },
    },
    {
      'name': 'get_page',
      'description': 'Get full content of a note page formatted in Markdown. Accepts either the page UUID or the page title (e.g. "Rules" or "Описание проекта").',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'pageId': {
            'type': 'string',
            'description': 'UUID or title of the page to retrieve',
          },
        },
        'required': ['pageId'],
      },
    },
    {
      'name': 'create_page',
      'description': 'Create a new note page in DraftFlow with title and Markdown content (headings, lists, code, quotes)',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'Title of the new page',
          },
          'content': {
            'type': 'string',
            'description': 'Markdown content for page body',
          },
          'parentId': {
            'type': 'string',
            'description': 'Optional parent page UUID for nested hierarchy',
          },
          'icon': {
            'type': 'string',
            'description': 'Optional emoji icon (e.g. 📝, 💡, 🚀)',
          },
        },
        'required': ['title'],
      },
    },
    {
      'name': 'update_page',
      'description': 'Update title and/or body content of an existing note page in DraftFlow',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'pageId': {
            'type': 'string',
            'description': 'UUID of the page to update',
          },
          'title': {
            'type': 'string',
            'description': 'Optional new title for the page',
          },
          'content': {
            'type': 'string',
            'description': 'Optional Markdown body content',
          },
          'append': {
            'type': 'boolean',
            'description': 'If true, appends content to existing blocks; if false (default), replaces blocks',
          },
        },
        'required': ['pageId'],
      },
    },
    {
      'name': 'delete_page',
      'description': 'Move a note page and its blocks to Trash in DraftFlow',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'pageId': {
            'type': 'string',
            'description': 'UUID of the page to trash',
          },
        },
        'required': ['pageId'],
      },
    },
    {
      'name': 'list_databases',
      'description': 'List all Notion-like relational databases in DraftFlow with column definitions and row counts',
      'inputSchema': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'query_database_rows',
      'description': 'Query rows from a relational database with cell values and optional keyword search in DraftFlow',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'databaseId': {
            'type': 'string',
            'description': 'UUID of the database to query',
          },
          'search': {
            'type': 'string',
            'description': 'Optional keyword to filter rows across title and cell properties',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum rows to return (default: 50)',
          },
        },
        'required': ['databaseId'],
      },
    },
    {
      'name': 'create_database_row',
      'description': 'Add a new row to a relational database in DraftFlow with column values',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'databaseId': {
            'type': 'string',
            'description': 'UUID of the database',
          },
          'title': {
            'type': 'string',
            'description': 'Primary title/name of the row item',
          },
          'properties': {
            'type': 'object',
            'description': 'Key-value map of column names (or IDs) to cell values',
          },
        },
        'required': ['databaseId', 'title'],
      },
    },
    {
      'name': 'update_database_row',
      'description': 'Update title or column properties of an existing row in a DraftFlow database',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'rowId': {
            'type': 'string',
            'description': 'UUID of the database row to update',
          },
          'title': {
            'type': 'string',
            'description': 'Optional updated title',
          },
          'properties': {
            'type': 'object',
            'description': 'Key-value map of column names to updated values',
          },
        },
        'required': ['rowId'],
      },
    },
    {
      'name': 'delete_database_row',
      'description': 'Delete a row from a relational database in DraftFlow',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'rowId': {
            'type': 'string',
            'description': 'UUID of the row to delete',
          },
        },
        'required': ['rowId'],
      },
    },
  ];
}
