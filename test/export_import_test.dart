import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/export_import_service.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/editor/components/database/database_models.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;
  late ExportImportService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(db);
    service = ExportImportService(repository: repository);
  });

  tearDown(() async {
    await db.close();
  });

  group('ExportImportService - Markdown', () {
    test('exportPageToMarkdown exports frontmatter, headings, code, and database tables', () async {
      // 1. Create a page with icon and cover
      final pageId = await repository.createPage(
        title: 'Project Roadmap',
        icon: '🚀',
        cover: '0xFF4A90E2',
      );

      // 2. Create a database block inside this page
      final dbId = await repository.createDatabase(
        title: 'Features',
        parentPageId: pageId,
      );
      final cols = await repository.getColumns(dbId);
      final tagsCol = cols.firstWhere((c) => c.name == 'Tags');
      final urlColId = await repository.addColumn(dbId, name: 'Website', type: 'url');

      await repository.createDatabaseRow(
        dbId,
        title: 'Authentication',
        properties: {
          tagsCol.id: 'done',
          urlColId: 'https://auth0.com',
        },
      );
      await repository.createDatabaseRow(
        dbId,
        title: 'Export Feature',
        properties: {
          tagsCol.id: 'in_progress',
          urlColId: 'github.com/export',
        },
      );

      // 3. Save nodes: Heading, Paragraph, Code block, Database
      final nodes = [
        headingNode(level: 2, text: 'Overview'),
        paragraphNode(text: 'This is the main roadmap document.'),
        codeBlockNode(
          language: 'dart',
          delta: Delta()..insert('void main() => print("Ready!");'),
        ),
        databaseBlockNode(databaseId: dbId),
      ];
      await repository.savePageNodes(pageId, nodes);

      // 4. Export to markdown
      final markdown = await service.exportPageToMarkdown(pageId);

      // Assertions
      expect(markdown.contains('---'), true);
      expect(markdown.contains('title: Project Roadmap'), true);
      expect(markdown.contains('icon: 🚀'), true);
      expect(markdown.contains('# Project Roadmap'), true);
      expect(markdown.contains('## Overview'), true);
      expect(markdown.contains('This is the main roadmap document.'), true);
      expect(markdown.contains('```dart'), true);
      expect(markdown.contains('void main() => print("Ready!");'), true);
      expect(markdown.contains('### 📊 Features'), true);
      expect(markdown.contains('| Name | Tags | Done | Website |'), true);
      expect(markdown.contains('Authentication'), true);
      expect(markdown.contains('[https://auth0.com](https://auth0.com)'), true);
      expect(markdown.contains('Export Feature'), true);
      expect(markdown.contains('[github.com/export](https://github.com/export)'), true);
    });

    test('parseMarkdown parses frontmatter and markdown body', () {
      const raw = '''
---
title: My Imported Note
icon: 📝
cover: preset_gradient_1
---

# My Imported Note

Here is a list:
- [ ] Task 1
- [x] Task 2

```python
print("Hello Python")
```
''';

      final parsed = service.parseMarkdown(raw);
      expect(parsed.title, 'My Imported Note');
      expect(parsed.icon, '📝');
      expect(parsed.cover, 'preset_gradient_1');
      expect(parsed.document.root.children.isNotEmpty, true);

      final types = parsed.document.root.children.map((n) => n.type).toList();
      expect(types.contains('todo_list'), true);
      expect(types.contains('code'), true);

      final codeNode = parsed.document.root.children.firstWhere((n) => n.type == 'code');
      expect(codeNode.attributes['language'], 'python');
      expect(codeNode.delta?.toPlainText().contains('Hello Python'), true);
    });

    test('importMarkdownAsNewPage creates new page and persists blocks', () async {
      const raw = '''
# Fast Document
This is imported from raw text.
- Item A
- Item B
''';

      final newPageId = await service.importMarkdownAsNewPage(raw);
      expect(newPageId.isNotEmpty, true);

      final page = await repository.getPage(newPageId);
      expect(page, isNotNull);
      expect(page!.title, 'Fast Document');

      final doc = await repository.loadPageDocument(newPageId);
      expect(doc.root.children.length >= 2, true);
    });
  });

  group('ExportImportService - Workspace JSON', () {
    test('exportWorkspaceJson and restoreWorkspaceJson roundtrip preserves all data', () async {
      // Setup initial data
      final page1Id = await repository.createPage(title: 'Page One', icon: '🌟');
      final page2Id = await repository.createPage(
        title: 'Subpage Two',
        parentId: page1Id,
      );

      final dbId = await repository.createDatabase(title: 'Table 1');
      await repository.createDatabaseRow(dbId, title: 'Row A');

      // Export
      final jsonStr = await service.exportWorkspaceJson();
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);

      expect(decoded['format'], 'notes_here_workspace_backup');
      expect(decoded['version'], 1);
      expect((decoded['pages'] as List).length >= 3, true); // page1, page2, row A
      expect((decoded['databases'] as List).length, 1);
      expect((decoded['databaseColumns'] as List).length, 3); // Name, Tags, Done

      // Create new clean DB and restore
      await db.close();
      final restoreDb = AppDatabase(NativeDatabase.memory());
      final restoreRepo = NotesRepository(restoreDb);
      final restoreService = ExportImportService(repository: restoreRepo);

      final summary = await restoreService.restoreWorkspaceJson(jsonStr);
      expect(summary.pagesCount, (decoded['pages'] as List).length);
      expect(summary.databasesCount, 1);

      final restoredPage1 = await restoreRepo.getPage(page1Id);
      expect(restoredPage1, isNotNull);
      expect(restoredPage1!.title, 'Page One');
      expect(restoredPage1.icon, '🌟');

      final restoredPage2 = await restoreRepo.getPage(page2Id);
      expect(restoredPage2, isNotNull);
      expect(restoredPage2!.parentId, page1Id);

      final restoredDb = await restoreRepo.getDatabase(dbId);
      expect(restoredDb, isNotNull);
      expect(restoredDb!.title, 'Table 1');

      await restoreDb.close();
    });

    test('saveExportToFile writes content to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('notes_export_test');
      final file = await ExportImportService.saveExportToFile(
        '# Test Content',
        'test_export.md',
        customDirectoryPath: tempDir.path,
      );

      expect(await file.exists(), true);
      expect(await file.readAsString(), '# Test Content');
      await tempDir.delete(recursive: true);
    });
  });

  group('ExportImportService - Notion CSV Database Import', () {
    const notionCsvSample1 = '\uFEFFДата,Время,описание,Select,Запрос,Formula,Text\n'
        '05/11/2026,1.5,Database Migration,Acme Corporation,https://jira.example.com:8443/browse/PROJECT-101,1470,1 ч. 30 мин.\n'
        '06/11/2026,1.33,Deploy Production Patch,Beta Industries,https://jira.example.com:8443/browse/PROJECT-202,1303.4,1 ч. 20 мин.';

    const notionCsvSample2 = 'описание,Formula,Select,Text,Время,Дата,Запрос\n'
        'Database Migration,1470,Acme Corporation,1 ч. 30 мин.,1.5,05/11/2026,https://jira.example.com:8443/browse/PROJECT-101\n'
        'Deploy Production Patch,1303.4,Beta Industries,1 ч. 20 мин.,1.33,06/11/2026,https://jira.example.com:8443/browse/PROJECT-202';

    test('extractTitleFromNotionFilename strips Notion hex ID and suffix', () {
      expect(
        ExportImportService.extractTitleFromNotionFilename(
          'Tasks 42ad9af9db04405ca0c377493b3290b2.csv',
        ),
        'Tasks',
      );
      expect(
        ExportImportService.extractTitleFromNotionFilename(
          '/path/to/Tasks 42ad9af9db04405ca0c377493b3290b2_all.csv',
        ),
        'Tasks',
      );
    });

    test('parseNotionCsv parses headers, rows and infers types accurately', () {
      final parsed1 = service.parseNotionCsv(
        notionCsvSample1,
        filename: 'Tasks 42ad9af9db04405ca0c377493b3290b2.csv',
      );

      expect(parsed1.title, 'Tasks');
      expect(parsed1.headers, ['Дата', 'Время', 'описание', 'Select', 'Запрос', 'Formula', 'Text']);
      expect(parsed1.rows.length, 2);
      expect(parsed1.titleColumnIndex, 2); // 'описание' is index 2

      final colTypes = {for (final c in parsed1.columns) c.name: c.type};
      expect(colTypes['Дата'], 'date');
      expect(colTypes['Время'], 'number');
      expect(colTypes['описание'], 'title');
      expect(colTypes['Select'], 'select');
      expect(colTypes['Запрос'], 'url');
      expect(colTypes['Formula'], 'number');
      expect(colTypes['Text'], 'text');

      // Sample 2 (_all.csv where 'описание' is index 0)
      final parsed2 = service.parseNotionCsv(
        notionCsvSample2,
        filename: 'Tasks 42ad9af9db04405ca0c377493b3290b2_all.csv',
      );
      expect(parsed2.titleColumnIndex, 0); // 'описание' is index 0
    });

    test('importNotionCsvAsDatabasePage creates page and populated database table', () async {
      final pageId = await service.importNotionCsvAsDatabasePage(
        notionCsvSample1,
        filename: 'Tasks 42ad9af9db04405ca0c377493b3290b2.csv',
      );

      // Verify page
      final page = await repository.getPage(pageId);
      expect(page, isNotNull);
      expect(page!.title, 'Tasks');
      expect(page.icon, '📊');

      // Verify page has database block
      final doc = await repository.loadPageDocument(pageId);
      expect(doc.root.children.length, 1);
      final dbNode = doc.root.children.first;
      expect(dbNode.type, databaseBlockType);

      final dbId = dbNode.attributes['databaseId'] as String;
      final database = await repository.getDatabase(dbId);
      expect(database, isNotNull);
      expect(database!.title, 'Tasks');

      // Verify columns
      final columns = await repository.getColumns(dbId);
      expect(columns.length, 7);
      expect(columns.any((c) => c.name == 'описание' && c.type == 'title'), true);
      expect(columns.any((c) => c.name == 'Дата' && c.type == 'date'), true);
      expect(columns.any((c) => c.name == 'Время' && c.type == 'number'), true);
      final selectCol = columns.firstWhere((c) => c.name == 'Select');
      expect(selectCol.type, 'select');
      final selectOpts = jsonDecode(selectCol.options!) as List;
      expect(selectOpts.length, 2); // 'Acme Corporation', 'Beta Industries'

      // Verify rows
      final rows = await repository.getDatabaseRows(dbId);
      expect(rows.length, 2);

      final row1 = rows.firstWhere((r) => r.title == 'Database Migration');
      final props1 = jsonDecode(row1.properties!) as Map<String, dynamic>;
      final dateCol = columns.firstWhere((c) => c.name == 'Дата');
      final timeCol = columns.firstWhere((c) => c.name == 'Время');
      final urlCol = columns.firstWhere((c) => c.name == 'Запрос');

      expect(props1[dateCol.id], '2026-11-05'); // Normalized date
      expect(props1[timeCol.id], 1.5);
      expect(props1[urlCol.id], 'https://jira.example.com:8443/browse/PROJECT-101');

      final row2 = rows.firstWhere((r) => r.title == 'Deploy Production Patch');
      final props2 = jsonDecode(row2.properties!) as Map<String, dynamic>;
      expect(props2[dateCol.id], '2026-11-06');
      expect(props2[timeCol.id], 1.33);
    });

    test('importNotionCsvIntoPage appends database table block into existing page', () async {
      final pageId = await repository.createPage(title: 'Parent Work Note');
      final dbId = await service.importNotionCsvIntoPage(
        pageId,
        notionCsvSample2,
        filename: 'Tasks.csv',
      );

      final doc = await repository.loadPageDocument(pageId);
      expect(doc.root.children.any((n) => n.type == databaseBlockType && n.attributes['databaseId'] == dbId), true);

      final rows = await repository.getDatabaseRows(dbId);
      expect(rows.length, 2);
    });

    test('import real Notion export file from filesystem if present', () async {
      final tempDir = await Directory.systemTemp.createTemp('notion_test');
      final tempFile = File('${tempDir.path}/Tasks 42ad9af9db04405ca0c377493b3290b2.csv');
      await tempFile.writeAsString(notionCsvSample1);

      final content = await tempFile.readAsString();
      final pageId = await service.importNotionCsvAsDatabasePage(
        content,
        filename: tempFile.path,
      );

      final page = await repository.getPage(pageId);
      expect(page, isNotNull);
      expect(page!.title, 'Tasks');

      final doc = await repository.loadPageDocument(pageId);
      final dbNode = doc.root.children.first;
      final dbId = dbNode.attributes['databaseId'] as String;
      final rows = await repository.getDatabaseRows(dbId);
      expect(rows.length, 2);

      await tempDir.delete(recursive: true);
    });
  });
}
