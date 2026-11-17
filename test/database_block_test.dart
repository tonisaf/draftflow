import 'package:notes_here/ui/common/app_icons.dart';
import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
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

  test('databaseBlockNode creates node with databaseId and title', () {
    final node = databaseBlockNode(
      databaseId: 'test-db-123',
      title: 'Project Roadmap',
    );

    expect(node.type, databaseBlockType);
    expect(node.attributes['databaseId'], 'test-db-123');
    expect(node.attributes['title'], 'Project Roadmap');
  });

  testWidgets(
    'renders DatabaseBlockComponentWidget with header, columns and rows',
    (tester) async {
      // 1. Prepare database and initial row
      final dbId = await repo.createDatabase(title: 'Sprint 1');
      final rowId = await repo.createDatabaseRow(
        dbId,
        title: 'Initial Task',
        properties: {'done': false},
      );

      String? navigatedPageId;

      final doc = Document(
        root: pageNode(
          children: [databaseBlockNode(databaseId: dbId, title: 'Sprint 1')],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                databaseBlockType: DatabaseBlockComponentBuilder(
                  repository: repo,
                  onNavigateToPage: (pageId) => navigatedPageId = pageId,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Title and count are displayed
      expect(find.text('Sprint 1'), findsOneWidget);
      expect(find.text('1 items'), findsOneWidget);

      // The add-row action and separator span the same grid as the data.
      expect(
        tester.getSize(find.byKey(const Key('database_add_row'))).width,
        tester.getSize(find.byKey(const Key('database_rows_viewport'))).width,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('database_add_row'))).dx,
        tester.getTopLeft(find.byKey(const Key('database_rows_viewport'))).dx,
      );

      final addButton = find.byKey(const Key('database_add_row_button'));
      expect(tester.getSize(addButton).width,
          lessThan(tester.getSize(find.byKey(const Key('database_add_row'))).width / 2));
      expect(tester.getCenter(addButton).dy,
          tester.getCenter(find.byType(TableSummaryCell).last).dy);

      // Verify Default Columns are displayed
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Verify Row title is displayed
      expect(find.text('Initial Task'), findsOneWidget);

      // Tap Checkbox to toggle 'done'
      final checkbox = find.byKey(const ValueKey('database_checkbox')).first;
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Verify property updated in repository
      final doneCol = (await repo.getColumns(dbId))
          .firstWhere((c) => c.name == 'Done');
      final rows = await repo.getDatabaseRows(dbId);
      expect(rows.length, 1);
      final props = jsonDecode(rows.first.properties!) as Map<String, dynamic>;
      expect(props[doneCol.id], true);

      // Tap '+ New page' button at the bottom
      expect(find.text('New page'), findsOneWidget);
      await tester.tap(find.text('New page'));
      await tester.pumpAndSettle();

      // Verify second row is created
      expect(find.text('2 items'), findsOneWidget);
      final updatedRows = await repo.getDatabaseRows(dbId);
      expect(updatedRows.length, 2);

      // Test Open as Page callback by hovering over the row
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Initial Task')));
      await tester.pumpAndSettle();

      final openIcon = find.byTooltip('Select row; double-click to open page').first;
      expect(openIcon, findsOneWidget);
      await tester.tap(openIcon);
      await tester.pump(const Duration(milliseconds:50));
      await tester.tap(openIcon);
      await tester.pumpAndSettle();

      // Verify Center Peek modal is displayed
      expect(find.byType(DatabaseRowModal), findsOneWidget);

      // Tap 'Open full page' in the modal header
      await tester.tap(find.byKey(const ValueKey('row_peek_open_full')));
      await tester.pumpAndSettle();

      expect(navigatedPageId, rowId);

      // Unmount widget cleanly before closing db and drain StreamQueryStore timers
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Select column allows creating new tags with color', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(title: 'Tag Test DB');
    await repo.createDatabaseRow(dbId, title: 'Row with Tag');

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Tag Test DB')],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
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

    // Find empty Tags cell and tap it
    final initialTagsCol = (await repo.getColumns(dbId))
        .firstWhere((c) => c.name == 'Tags');
    final emptyTagFinder = find
        .byKey(ValueKey('select_cell_${initialTagsCol.id}'))
        .first;
    expect(emptyTagFinder, findsOneWidget);
    await tester.tap(emptyTagFinder);
    await tester.pumpAndSettle();

    // Tap 'New tag...'
    expect(find.text('New tag...'), findsOneWidget);
    await tester.tap(find.text('New tag...'));
    await tester.pumpAndSettle();

    // Dialog 'New Tag' should be open
    expect(find.text('New Tag'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Urgent');
    await tester.pumpAndSettle();

    // Tap 'Create Tag'
    await tester.tap(find.text('Create Tag'));
    await tester.pumpAndSettle();

    // Verify tag appears in cell
    expect(find.text('Urgent'), findsOneWidget);

    // Verify row properties and column options in repo
    final rows = await repo.getDatabaseRows(dbId);
    final tagsCol = (await repo.getColumns(dbId))
        .firstWhere((c) => c.name == 'Tags');
    final options = jsonDecode(tagsCol.options!) as List<dynamic>;
    expect(options.any((o) => o['label'] == 'Urgent'), isTrue);

    final rowProps = jsonDecode(rows.first.properties!) as Map<String, dynamic>;
    expect(rowProps[tagsCol.id], startsWith('opt_'));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Date column allows picking date via showDatePicker', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(title: 'Date Test DB');
    final dateColId = await repo.addColumn(
      dbId,
      name: 'Due Date',
      type: 'date',
    );
    await repo.createDatabaseRow(dbId, title: 'Task with Deadline');

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Date Test DB')],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
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

    // Tap empty date cell
    final dateCell = find.byKey(ValueKey('date_cell_$dateColId')).first;
    expect(dateCell, findsOneWidget);
    await tester.tap(dateCell);
    await tester.pumpAndSettle();

    // Verify DatePicker is shown and confirm default selected date
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Verify date is saved to repo row
    final rows = await repo.getDatabaseRows(dbId);
    final props = jsonDecode(rows.first.properties!) as Map<String, dynamic>;
    expect(props[dateColId], isNotNull);
    expect(props[dateColId].toString(), contains('-'));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Center Peek DatabaseRowModal renders properties and page editor',
    (tester) async {
      final dbId = await repo.createDatabase(title: 'Sprint DB');
      await repo.createDatabaseRow(
        dbId,
        title: 'Detailed Task',
        properties: {'done': false},
      );

      final doc = Document(
        root: pageNode(
          children: [databaseBlockNode(databaseId: dbId, title: 'Sprint DB')],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
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

      // Hover row and open modal
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Detailed Task')));
      await tester.pumpAndSettle();

      final openIcon = find.byTooltip('Select row; double-click to open page').first;
      await tester.tap(openIcon);
      await tester.pump(const Duration(milliseconds:50));
      await tester.tap(openIcon);
      await tester.pumpAndSettle();

      // Verify modal is shown
      expect(find.byType(DatabaseRowModal), findsOneWidget);

      // Verify properties inspector inside modal shows columns
      expect(find.text('Tags'), findsWidgets);
      expect(find.text('Done'), findsWidgets);

      // Close modal via close button
      await tester.tap(find.byKey(const ValueKey('row_peek_close')));
      await tester.pumpAndSettle();

      // Modal is dismissed
      expect(find.byType(DatabaseRowModal), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Sorting database rows by column ascending and descending', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(title: 'Sort DB');
    await repo.createDatabaseRow(dbId, title: 'Banana');
    await repo.createDatabaseRow(dbId, title: 'Apple');
    await repo.createDatabaseRow(dbId, title: 'Cherry');

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Sort DB')],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
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

    // Tap Sort button in header
    expect(find.byTooltip('Sort'), findsOneWidget);
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();

    // Select 'Name' column to sort by
    expect(find.text('Name'), findsWidgets);
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();

    // Verify rows are ordered alphabetically: Apple, Banana, Cherry
    final yApple = tester.getTopLeft(find.text('Apple')).dy;
    final yBanana = tester.getTopLeft(find.text('Banana')).dy;
    final yCherry = tester.getTopLeft(find.text('Cherry')).dy;
    expect(yApple < yBanana, isTrue);
    expect(yBanana < yCherry, isTrue);

    // Header badge now shows 'Name ↑'
    expect(find.text('Name ↑'), findsOneWidget);

    // Toggle sort direction via column options or sort button
    await tester.tap(find.text('Name ↑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descending ↓'));
    await tester.pumpAndSettle();

    // Verify rows are reversed: Cherry, Banana, Apple
    final yCherryDesc = tester.getTopLeft(find.text('Cherry')).dy;
    final yBananaDesc = tester.getTopLeft(find.text('Banana')).dy;
    final yAppleDesc = tester.getTopLeft(find.text('Apple')).dy;
    expect(yCherryDesc < yBananaDesc, isTrue);
    expect(yBananaDesc < yAppleDesc, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Filtering database rows with filter dialog and quick search', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(title: 'Filter DB');
    final cols = await repo.getColumns(dbId);
    final doneCol = cols.firstWhere((c) => c.name == 'Done');

    await repo.createDatabaseRow(
      dbId,
      title: 'Buy Milk',
      properties: {doneCol.id: true},
    );
    await repo.createDatabaseRow(
      dbId,
      title: 'Write Code',
      properties: {doneCol.id: false},
    );
    await repo.createDatabaseRow(
      dbId,
      title: 'Read Book',
      properties: {doneCol.id: false},
    );

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Filter DB')],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
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

    // Initially 3 items
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('Write Code'), findsOneWidget);
    expect(find.text('Read Book'), findsOneWidget);

    // 1. Test Filter Dialog: filter by Done: Unchecked only
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Filter Database'), findsOneWidget);

    // Select Done column
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();

    // Select Unchecked only
    await tester.tap(find.text('Checked only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unchecked only').last);
    await tester.pumpAndSettle();

    // Tap Apply
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Verify filtered count and items
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Buy Milk'), findsNothing);
    expect(find.text('Write Code'), findsOneWidget);
    expect(find.text('Read Book'), findsOneWidget);

    // Clear filters
    await tester.tap(find.text('Filter (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    // Verify all 3 items are back
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('Buy Milk'), findsOneWidget);

    // Test Filter Dialog with Select (Tags) column: ensures no record type covariance crash
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tags').last);
    await tester.pumpAndSettle();
    expect(find.text('To Do'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 2. Test Quick Search
    final searchIcon = find.byIcon(AppIcons.search);
    expect(searchIcon, findsOneWidget);
    await tester.tap(searchIcon);
    await tester.pumpAndSettle();

    final searchField = find.widgetWithText(TextField, 'Search...');
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Milk');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Buy Milk'), findsOneWidget);
    expect(find.text('Write Code'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'database cells and title commit on blur without pressing enter',
    (tester) async {
      final dbId = await repo.createDatabase(title: 'Original DB Title');
      final colId = await repo.addColumn(dbId, name: 'Notes', type: 'text');
      final rowId = await repo.createDatabaseRow(
        dbId,
        title: 'Original Row Title',
        properties: {colId: 'Old Text'},
      );

      final doc = Document(
        root: pageNode(
          children: [
            databaseBlockNode(databaseId: dbId, title: 'Original DB Title'),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
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

      // 1. Edit row title cell and blur (without pressing enter)
      final titleField = find.widgetWithText(TextField, 'Original Row Title');
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'Updated Row Title');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final updatedRow = await repo.getPage(rowId);
      expect(updatedRow?.title, 'Updated Row Title');

      // 2. Edit inline cell and blur
      final notesField = find.widgetWithText(TextField, 'Old Text');
      expect(notesField, findsOneWidget);
      await tester.enterText(notesField, 'New Blurred Text');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final rowsAfter = await repo.getDatabaseRows(dbId);
      final propsAfter =
          jsonDecode(rowsAfter.first.properties!) as Map<String, dynamic>;
      expect(propsAfter[colId], 'New Blurred Text');

      // 3. Edit database table title and blur
      final dbTitleField = find.widgetWithText(TextField, 'Original DB Title');
      expect(dbTitleField, findsOneWidget);
      await tester.enterText(dbTitleField, 'Renamed Database Title');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final dbAfter = await repo.getDatabase(dbId);
      expect(dbAfter?.title, 'Renamed Database Title');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'URL column allows entering url, displays link, and persists value on blur',
    (tester) async {
      final dbId = await repo.createDatabase(title: 'Links DB');
      final urlColId = await repo.addColumn(dbId, name: 'Website', type: 'url');
      await repo.createDatabaseRow(
        dbId,
        title: 'Site 1',
        properties: {urlColId: 'https://flutter.dev'},
      );

      final doc = Document(
        root: pageNode(
          children: [databaseBlockNode(databaseId: dbId, title: 'Links DB')],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
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

      // Verify existing link is cleanly displayed without protocol
      expect(find.text('flutter.dev'), findsOneWidget);
      expect(find.byIcon(AppIcons.link), findsWidgets);

      // Double tap on the url to edit
      await tester.tap(find.text('flutter.dev'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('flutter.dev'));
      await tester.pumpAndSettle();

      final urlField = find.widgetWithText(TextField, 'https://flutter.dev');
      expect(urlField, findsOneWidget);

      await tester.enterText(urlField, 'https://dart.dev');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Verify persisted in DB
      final rowsAfter = await repo.getDatabaseRows(dbId);
      final propsAfter =
          jsonDecode(rowsAfter.first.properties!) as Map<String, dynamic>;
      expect(propsAfter[urlColId], 'https://dart.dev');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Rename column commits inline property name without a dialog', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(title: 'Columns DB');
    final colId = await repo.addColumn(
      dbId,
      name: 'Old Col Name',
      type: 'text',
    );

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Columns DB')],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
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

    expect(find.text('Old Col Name'), findsOneWidget);

    // Tap on column header 'Old Col Name' to open header menu
    await tester.tap(find.text('Old Col Name'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    final inputField = find.widgetWithText(TextField, 'Old Col Name');
    expect(inputField, findsOneWidget);

    await tester.enterText(inputField, 'New Col Name');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Column name updated in repository
    final cols = await repo.getColumns(dbId);
    final renamedCol = cols.firstWhere((c) => c.id == colId);
    expect(renamedCol.name, 'New Col Name');

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Change column type to URL converts column and updates repository',
    (tester) async {
      final dbId = await repo.createDatabase(title: 'Convert DB');
      final colId = await repo.addColumn(
        dbId,
        name: 'Web Resource',
        type: 'text',
      );

      final doc = Document(
        root: pageNode(
          children: [databaseBlockNode(databaseId: dbId, title: 'Convert DB')],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
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

      // Tap column header to open menu
      await tester.tap(find.text('Web Resource'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.byType(ModernSelectPicker<String>));
      await tester.pumpAndSettle();

      // Select 'URL Link' from dialog
      final urlLinkOption = find.text('URL Link');
      expect(urlLinkOption, findsOneWidget);
      await tester.tap(urlLinkOption);
      await tester.pumpAndSettle();

      // Column type updated in repo to 'url'
      final cols = await repo.getColumns(dbId);
      final updatedCol = cols.firstWhere((c) => c.id == colId);
      expect(updatedCol.type, 'url');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Filter by URL column filters rows matching domain', (
    tester,
  ) async {
    final dbId = await repo.createDatabase(title: 'Filter URL DB');
    final urlColId = await repo.addColumn(dbId, name: 'Docs', type: 'url');

    await repo.createDatabaseRow(
      dbId,
      title: 'Flutter Website',
      properties: {urlColId: 'flutter.dev'},
    );
    await repo.createDatabaseRow(
      dbId,
      title: 'GitHub Repo',
      properties: {urlColId: 'github.com/flutter/flutter'},
    );

    final doc = Document(
      root: pageNode(
        children: [databaseBlockNode(databaseId: dbId, title: 'Filter URL DB')],
      ),
    );

    final editorState = EditorState(document: doc);

    await tester.pumpWidget(
      MaterialApp(
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

    expect(find.text('2 items'), findsOneWidget);

    // Open Filter dialog
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();

    // Select Docs column
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Docs').last);
    await tester.pumpAndSettle();

    // Enter search text
    final filterField = find.descendant(
      of: find.byType(ModernDialog),
      matching: find.byType(TextField),
    );
    expect(filterField, findsOneWidget);
    await tester.enterText(filterField, 'github');
    await tester.pumpAndSettle();

    // Apply
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Check filtered results
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('GitHub Repo'), findsOneWidget);
    expect(find.text('Flutter Website'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Move column left and right via menu reorders columns in database block',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dbId = await repo.createDatabase(title: 'Move Columns DB');
      // Default columns: Name (0), Tags (1), Done (2)
      await repo.addColumn(dbId, name: 'Website', type: 'url');
      // Order now: Name, Tags, Done, Website

      final doc = Document(
        root: pageNode(
          children: [
            databaseBlockNode(databaseId: dbId, title: 'Move Columns DB'),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
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

      // 1. Tap on Done header to open menu
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Menu should offer 'Move right'
      final moveRight = find.text('Move right');
      expect(moveRight, findsOneWidget);
      await tester.tap(moveRight);
      await tester.pumpAndSettle();

      // Order should now be: Name, Tags, Website, Done
      var cols = await repo.getColumns(dbId);
      expect(cols.map((c) => c.name).toList(), [
        'Name',
        'Tags',
        'Website',
        'Done',
      ]);

      // 2. Tap on Done header again and move left
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final moveLeft = find.text('Move left');
      expect(moveLeft, findsOneWidget);
      await tester.tap(moveLeft);
      await tester.pumpAndSettle();

      // Order restored: Name, Tags, Done, Website
      cols = await repo.getColumns(dbId);
      expect(cols.map((c) => c.name).toList(), [
        'Name',
        'Tags',
        'Done',
        'Website',
      ]);

      // 3. Test Drag and drop reordering:
      // Drag Website header left over Done header
      final websiteFinder = find.text('Website');
      final doneFinder = find.text('Done');
      final doneCenter = tester.getCenter(doneFinder);
      final gesture = await tester.startGesture(
        tester.getCenter(websiteFinder),
      );
      await gesture.moveTo(doneCenter);
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      cols = await repo.getColumns(dbId);
      expect(cols.map((c) => c.name).toList(), [
        'Name',
        'Tags',
        'Website',
        'Done',
      ]);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
