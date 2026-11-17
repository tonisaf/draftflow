import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/db/database_rows_query.dart';
import 'package:notes_here/data/model/database_paste.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/app_localizations.dart';
import 'package:notes_here/ui/common/app_icons.dart';
import 'package:notes_here/ui/editor/components/database/database_property_menu.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('databasePropertyTypes contains status, checkbox, multi_select', () {
    final values = databasePropertyTypes.map((t) => t.value).toList();
    expect(values, contains('status'));
    expect(values, contains('checkbox'));
    expect(values, contains('multi_select'));
    expect(values, contains('select'));
    expect(values, contains('text'));
    expect(values, contains('number'));
  });

  test('iconForColumnType returns correct icons for status, checkbox, multi_select', () {
    expect(iconForColumnType('status'), AppIcons.circleLefthalfFill);
    expect(iconForColumnType('checkbox'), AppIcons.checkmarkSquare);
    expect(iconForColumnType('multi_select'), AppIcons.tag);
  });

  test('addColumn with type status automatically populates default options', () async {
    final dbId = await repo.createDatabase(title: 'Test DB', initialColumns: []);
    final colId = await repo.addColumn(dbId, name: 'State', type: 'status');

    final cols = await repo.getColumns(dbId);
    final statusCol = cols.firstWhere((c) => c.id == colId);
    expect(statusCol.type, 'status');
    expect(statusCol.options, isNotNull);

    final options = jsonDecode(statusCol.options!) as List;
    expect(options.length, 3);
    expect(options[0]['id'], 'not_started');
    expect(options[1]['id'], 'in_progress');
    expect(options[2]['id'], 'done');
  });

  test('validDatabasePasteValue supports status, multi_select, checkbox', () {
    final options = jsonEncode([
      {'id': 'todo', 'label': 'To Do'},
      {'id': 'done', 'label': 'Done'},
    ]);
    final statusCol = DatabaseColumn(
      id: 'c1',
      databaseId: 'd1',
      name: 'Status',
      type: 'status',
      options: options,
      width: 160,
      orderKey: 'a',
      createdAt: DateTime.now(),
    );
    final multiCol = DatabaseColumn(
      id: 'c2',
      databaseId: 'd1',
      name: 'Tags',
      type: 'multi_select',
      options: options,
      width: 160,
      orderKey: 'b',
      createdAt: DateTime.now(),
    );
    final checkCol = DatabaseColumn(
      id: 'c3',
      databaseId: 'd1',
      name: 'Done',
      type: 'checkbox',
      width: 100,
      orderKey: 'c',
      createdAt: DateTime.now(),
    );

    expect(validDatabasePasteValue(statusCol, 'todo'), isTrue);
    expect(validDatabasePasteValue(statusCol, 'invalid'), isFalse);

    expect(validDatabasePasteValue(multiCol, ['todo', 'done']), isTrue);
    expect(validDatabasePasteValue(multiCol, ['todo', 'invalid']), isFalse);

    expect(validDatabasePasteValue(checkCol, true), isTrue);
    expect(validDatabasePasteValue(checkCol, false), isTrue);
    expect(validDatabasePasteValue(checkCol, 'true'), isTrue);
  });

  test('database_rows_query correctly queries checkbox, status, multi_select', () async {
    final dbId = await repo.createDatabase(
      title: 'Query DB',
      initialColumns: [
        (name: 'Title', type: 'title', options: null, width: 200.0),
        (
          name: 'Status',
          type: 'status',
          options: jsonEncode([
            {'id': 's1', 'label': 'Open'},
            {'id': 's2', 'label': 'Closed'},
          ]),
          width: 160.0,
        ),
        (
          name: 'Tags',
          type: 'multi_select',
          options: jsonEncode([
            {'id': 't1', 'label': 'Bug'},
            {'id': 't2', 'label': 'Feature'},
          ]),
          width: 160.0,
        ),
        (name: 'Checked', type: 'checkbox', options: null, width: 100.0),
      ],
    );

    final cols = await repo.getColumns(dbId);
    final statusCol = cols.firstWhere((c) => c.name == 'Status');
    final tagsCol = cols.firstWhere((c) => c.name == 'Tags');
    final checkCol = cols.firstWhere((c) => c.name == 'Checked');

    await repo.createDatabaseRow(
      dbId,
      title: 'Row 1',
      properties: {
        statusCol.id: 's1',
        tagsCol.id: ['t1'],
        checkCol.id: true,
      },
    );
    await repo.createDatabaseRow(
      dbId,
      title: 'Row 2',
      properties: {
        statusCol.id: 's2',
        tagsCol.id: ['t1', 't2'],
        checkCol.id: false,
      },
    );

    // 1. Filter checkbox is_true
    final checkTrueQuery = buildDatabaseRowsQuery(
      dbId,
      cols,
      filters: [
        DatabaseFilterRule(columnId: checkCol.id, operator: 'is_true'),
      ],
    );
    expect(checkTrueQuery.sql, contains('p.database_id = ?1'));

    // 2. Filter multi_select contains
    final multiQuery = buildDatabaseRowsQuery(
      dbId,
      cols,
      filters: [
        DatabaseFilterRule(columnId: tagsCol.id, operator: 'contains', value: 't2'),
      ],
    );
    expect(multiQuery.variables.any((v) => v.value == 't2'), isTrue);

    // 3. Filter status equals
    final statusQuery = buildDatabaseRowsQuery(
      dbId,
      cols,
      filters: [
        DatabaseFilterRule(columnId: statusCol.id, operator: 'equals', value: 's1'),
      ],
    );
    expect(statusQuery.variables.any((v) => v.value == 's1'), isTrue);
  });

  testWidgets('renders and interacts with Status, Checkbox, and Multi-select cells', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(
      title: 'Interactive DB',
      initialColumns: [
        (name: 'Name', type: 'title', options: null, width: 150.0),
        (
          name: 'State',
          type: 'status',
          options: jsonEncode([
            {'id': 'not_started', 'label': 'Not started', 'color': '0xFF9E9E9E'},
            {'id': 'in_progress', 'label': 'In progress', 'color': '0xFF2196F3'},
            {'id': 'done', 'label': 'Done', 'color': '0xFF4CAF50'},
          ]),
          width: 150.0,
        ),
        (
          name: 'Tags',
          type: 'multi_select',
          options: jsonEncode([
            {'id': 'frontend', 'label': 'Frontend', 'color': '0xFF4A90E2'},
            {'id': 'urgent', 'label': 'Urgent', 'color': '0xFFD0021B'},
          ]),
          width: 160.0,
        ),
        (name: 'IsComplete', type: 'checkbox', options: null, width: 80.0),
      ],
    );

    final cols = await repo.getColumns(dbId);
    final stateCol = cols.firstWhere((c) => c.name == 'State');
    final tagsCol = cols.firstWhere((c) => c.name == 'Tags');
    final checkCol = cols.firstWhere((c) => c.name == 'IsComplete');

    final rowId = await repo.createDatabaseRow(
      dbId,
      title: 'Task Alpha',
      properties: {
        stateCol.id: 'not_started',
        tagsCol.id: ['frontend', 'urgent'],
        checkCol.id: false,
      },
    );

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Interactive DB')],
      ),
    );
    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: editorState,
            blockComponentBuilders: {
              ...standardBlockComponentBuilderMap,
              databaseBlockType: DatabaseBlockComponentBuilder(
                repository: repo,
              ),
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify row data rendered
    expect(find.text('Task Alpha'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
    expect(find.text('Frontend'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.byKey(const ValueKey('database_checkbox')), findsOneWidget);

    // 1. Toggle checkbox
    await tester.tap(find.byKey(const ValueKey('database_checkbox')));
    await tester.pumpAndSettle();

    var updatedRow = await db.getPageById(rowId);
    var updatedProps = jsonDecode(updatedRow!.properties!);
    expect(updatedProps[checkCol.id], isTrue);

    // 2. Change status
    await tester.tap(find.byKey(ValueKey('status_cell_${stateCol.id}')));
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('In progress'));
    await tester.pumpAndSettle();

    updatedRow = await db.getPageById(rowId);
    updatedProps = jsonDecode(updatedRow!.properties!);
    expect(updatedProps[stateCol.id], 'in_progress');

    // 3. Toggle multi-select tags
    await tester.tap(find.byKey(ValueKey('multi_select_cell_${tagsCol.id}')));
    await tester.pumpAndSettle();

    // Deselect 'urgent' from popover
    await tester.tap(find.text('Urgent').last);
    await tester.pumpAndSettle();

    // Tap outside to close popover
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    updatedRow = await db.getPageById(rowId);
    updatedProps = jsonDecode(updatedRow!.properties!);
    expect(updatedProps[tagsCol.id], ['frontend']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
