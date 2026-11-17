import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/mcp/draftflow_db_client.dart';
import 'package:notes_here/mcp/draftflow_mcp_server.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late DraftFlowDbClient client;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('draftflow_mcp_test_');
    dbPath = '${tempDir.path}/test_db.sqlite';

    // Initialize test SQLite database with DraftFlow schema
    final rawDb = sqlite3.open(dbPath);
    rawDb.execute('''
      CREATE TABLE pages (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        parent_id TEXT NULL,
        icon TEXT NULL,
        cover TEXT NULL,
        order_key TEXT NULL,
        database_id TEXT NULL,
        properties TEXT NULL,
        title_folded TEXT NULL,
        properties_folded TEXT NULL,
        created_at INTEGER NOT NULL,
        trashed_at INTEGER NULL,
        trash_batch_id TEXT NULL
      );

      CREATE TABLE blocks (
        id TEXT NOT NULL PRIMARY KEY,
        page_id TEXT NOT NULL,
        parent_id TEXT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        order_key TEXT NOT NULL,
        trashed_at INTEGER NULL,
        trash_batch_id TEXT NULL
      );

      CREATE TABLE databases (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL DEFAULT 'Untitled Database',
        icon TEXT NULL,
        parent_page_id TEXT NULL,
        created_at INTEGER NOT NULL,
        trashed_at INTEGER NULL,
        trash_batch_id TEXT NULL
      );

      CREATE TABLE database_columns (
        id TEXT NOT NULL PRIMARY KEY,
        database_id TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        options TEXT NULL,
        width REAL NOT NULL DEFAULT 160.0,
        order_key TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
    rawDb.dispose();

    client = DraftFlowDbClient.open(dbPath);
  });

  tearDown(() {
    client.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DraftFlowDbClient - Pages CRUD', () {
    test('creates and retrieves a page with markdown content', () {
      final created = client.createPage(
        title: 'Meeting Notes',
        content: '''# Agenda
- Discuss roadmap
- Plan release

```dart
void main() {}
```
> Important quote
''',
        icon: '📋',
      );

      expect(created['success'], isTrue);
      final pageId = created['pageId'] as String;

      final page = client.getPage(pageId);
      expect(page, isNotNull);
      expect(page!['title'], 'Meeting Notes');
      expect(page['icon'], '📋');
      expect(page['markdown'], contains('# Agenda'));
      expect(page['markdown'], contains('- Discuss roadmap'));
      expect(page['markdown'], contains('```dart'));
      expect(page['markdown'], contains('> Important quote'));
      expect(page['blocksCount'], 5);
    });

    test('searchNotes finds pages by title and block content', () {
      client.createPage(
        title: 'Flutter Architecture',
        content: 'Explaining state management and provider pattern.',
      );
      client.createPage(
        title: 'Shopping List',
        content: 'Apples, milk, bread.',
      );

      final titleSearch = client.searchNotes('Flutter');
      expect(titleSearch.length, 1);
      expect(titleSearch.first['title'], 'Flutter Architecture');

      final contentSearch = client.searchNotes('provider');
      expect(contentSearch.length, 1);
      expect(contentSearch.first['title'], 'Flutter Architecture');

      final noResults = client.searchNotes('NonExistentKeyword');
      expect(noResults, isEmpty);
    });

    test('updates page title and content', () {
      final created = client.createPage(title: 'Original Title', content: 'Original body');
      final pageId = created['pageId'] as String;

      client.updatePage(pageId, title: 'Updated Title', content: 'New body paragraph');

      final updated = client.getPage(pageId);
      expect(updated!['title'], 'Updated Title');
      expect(updated['markdown'], contains('New body paragraph'));
      expect(updated['markdown'], isNot(contains('Original body')));
    });

    test('soft deletes page', () {
      final created = client.createPage(title: 'To Be Deleted');
      final pageId = created['pageId'] as String;

      client.deletePage(pageId);

      expect(client.getPage(pageId), isNull);
      expect(client.listPages(), isEmpty);
    });
  });

  group('DraftFlowDbClient - Databases CRUD', () {
    test('queries, creates, and updates database rows', () {
      // 1. Setup a test database with columns
      client.db.execute('''
        INSERT INTO databases (id, title, icon, created_at)
        VALUES ('db-1', 'Projects', '📁', 1700000000);

        INSERT INTO database_columns (id, database_id, name, type, order_key, created_at)
        VALUES ('col-status', 'db-1', 'Status', 'select', 'a0', 1700000000);

        INSERT INTO database_columns (id, database_id, name, type, order_key, created_at)
        VALUES ('col-prio', 'db-1', 'Priority', 'number', 'a1', 1700000000);
      ''');

      final dbs = client.listDatabases();
      expect(dbs.length, 1);
      expect(dbs.first['title'], 'Projects');
      expect(dbs.first['columns'].length, 2);

      // 2. Create row
      final createdRow = client.createDatabaseRow(
        'db-1',
        title: 'Mobile App Redesign',
        properties: {'Status': 'In Progress', 'Priority': 1},
      );
      expect(createdRow['success'], isTrue);
      final rowId = createdRow['rowId'] as String;

      // 3. Query rows
      final rows = client.queryDatabaseRows('db-1');
      expect(rows.length, 1);
      expect(rows.first['title'], 'Mobile App Redesign');
      expect(rows.first['properties']['Status'], 'In Progress');
      expect(rows.first['properties']['Priority'], 1);

      // 4. Update row
      client.updateDatabaseRow(rowId, title: 'Mobile App Redesign V2', properties: {'Status': 'Done'});
      final updatedRows = client.queryDatabaseRows('db-1');
      expect(updatedRows.first['title'], 'Mobile App Redesign V2');
      expect(updatedRows.first['properties']['Status'], 'Done');
      expect(updatedRows.first['properties']['Priority'], 1); // preserved

      // 5. Delete row
      client.deleteDatabaseRow(rowId);
      expect(client.queryDatabaseRows('db-1'), isEmpty);
    });
  });

  group('DraftFlowMcpServer - JSON-RPC Protocol', () {
    late DraftFlowMcpServer server;

    setUp(() {
      server = DraftFlowMcpServer(client: client);
    });

    test('responds to initialize', () async {
      final res = await server.handleMessage({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {},
      });

      expect(res!['id'], 1);
      expect(res['result']['serverInfo']['name'], 'draftflow');
      expect(res['result']['protocolVersion'], '2024-11-05');
      expect(res['result']['capabilities']['tools'], isNotNull);
    });

    test('lists available tools in tools/list', () async {
      final res = await server.handleMessage({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
        'params': {},
      });

      final tools = res!['result']['tools'] as List<dynamic>;
      final toolNames = tools.map((t) => t['name']).toList();

      expect(toolNames, contains('search_notes'));
      expect(toolNames, contains('list_pages'));
      expect(toolNames, contains('get_page'));
      expect(toolNames, contains('create_page'));
      expect(toolNames, contains('update_page'));
      expect(toolNames, contains('delete_page'));
      expect(toolNames, contains('list_databases'));
      expect(toolNames, contains('query_database_rows'));
      expect(toolNames, contains('create_database_row'));
      expect(toolNames, contains('update_database_row'));
      expect(toolNames, contains('delete_database_row'));
    });

    test('executes tools/call create_page and get_page', () async {
      // 1. Create page via tool
      final createRes = await server.handleMessage({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'create_page',
          'arguments': {
            'title': 'AI Generated Plan',
            'content': '# Step 1\nExecute MCP server integration.',
          },
        },
      });

      expect(createRes!['result']['content'][0]['text'], contains('Created page "AI Generated Plan"'));

      // 2. Search note
      final searchRes = await server.handleMessage({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {
          'name': 'search_notes',
          'arguments': {'query': 'Generated'},
        },
      });

      final searchJson = jsonDecode(searchRes!['result']['content'][0]['text'] as String) as List<dynamic>;
      expect(searchJson.length, 1);
      final pageId = searchJson.first['id'] as String;

      // 3. Get page
      final getRes = await server.handleMessage({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {
          'name': 'get_page',
          'arguments': {'pageId': pageId},
        },
      });

      expect(getRes!['result']['content'][0]['text'], contains('# AI Generated Plan'));
      expect(getRes['result']['content'][0]['text'], contains('Execute MCP server integration.'));
    });
  });
}
