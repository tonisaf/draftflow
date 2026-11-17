import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/common/export_import_dialog.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  );
}

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('ExportImportDialog renders tabs and exports markdown',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pageId = await repository.createPage(
      title: 'Roadmap Note',
      icon: '🗺️',
    );

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showExportImportDialog(
              context,
              repository: repository,
              currentPageId: pageId,
              currentPageTitle: 'Roadmap Note',
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog tabs
    expect(find.text('Export (.md)'), findsOneWidget);
    expect(find.text('Import (.md)'), findsOneWidget);
    expect(find.text('Notion / CSV'), findsOneWidget);
    expect(find.text('Backup (JSON)'), findsOneWidget);

    // Verify Export tab contents
    expect(find.text('Roadmap Note'), findsOneWidget);
    expect(find.text('Copy to Clipboard'), findsOneWidget);
    expect(find.text('Save .md to Downloads'), findsOneWidget);

    // Switch to Import Markdown tab
    await tester.tap(find.text('Import (.md)'));
    await tester.pumpAndSettle();

    expect(find.text('Import as New Page'), findsOneWidget);
    expect(find.text('Load File'), findsOneWidget);

    // Switch to Notion / CSV tab
    await tester.tap(find.text('Notion / CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Import as New Database Page'), findsOneWidget);
    expect(find.text('Load File'), findsOneWidget);

    // Switch to Workspace Backup tab
    await tester.ensureVisible(find.text('Backup (JSON)'));
    await tester.tap(find.text('Backup (JSON)'));
    await tester.pumpAndSettle();

    expect(find.text('Export Workspace Backup'), findsOneWidget);
    expect(find.text('Restore Workspace from JSON'), findsOneWidget);
    expect(find.text('Save Backup to Downloads'), findsOneWidget);
    expect(find.text('Restore Workspace'), findsOneWidget);
  });

  testWidgets('PageEditorView renders page more actions button and opens popover',
      (tester) async {
    final pageId = await repository.createPage(title: 'Action Page');

    await tester.pumpWidget(
      createTestApp(
        PageEditorView(
          repository: repository,
          pageId: pageId,
          title: 'Action Page',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final moreButton = find.byKey(const Key('page_more_actions_button'));
    expect(moreButton, findsOneWidget);

    // Tap more actions button
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Verify popover menu items
    expect(find.text('Export Page'), findsOneWidget);
    expect(find.text('Export Markdown...'), findsOneWidget);
    expect(find.text('Copy Markdown'), findsOneWidget);
    expect(find.text('Save .md to Downloads'), findsOneWidget);
    expect(find.text('Import Content'), findsOneWidget);
    expect(find.text('Import Notion / CSV...'), findsOneWidget);
    expect(find.text('Import Markdown (.md)...'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Backup & Restore...'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets('Notion CSV tab parses CSV, displays table grid and allows column type change',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? importedPageId;

    await tester.pumpWidget(
      createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showExportImportDialog(
              context,
              repository: repository,
              initialMode: ExportImportMode.notionCsv,
              onNavigateToPage: (id) => importedPageId = id,
            ),
            child: const Text('Open Notion Dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Notion Dialog'));
    await tester.pumpAndSettle();

    // Verify Notion CSV tab is active
    expect(find.text('Import as New Database Page'), findsOneWidget);
    expect(find.text('Browse...'), findsOneWidget);

    // Enter raw CSV in the text field
    const csv =
        'описание,Время,Дата\nЗадача 1,2.5,05/11/2026\nЗадача 2,1.0,06/11/2026';
    await tester.enterText(find.byType(TextField).last, csv);
    await tester.pumpAndSettle();

    // Verify stats & column chips appear
    expect(find.text('2 rows • 3 columns'), findsWidgets);
    expect(find.text('(title)'), findsOneWidget);
    expect(find.text('(number)'), findsOneWidget);
    expect(find.text('(date)'), findsOneWidget);

    // Verify table grid preview is shown with row numbers & data
    expect(find.text('Table Preview'), findsOneWidget);
    expect(find.text('Raw CSV'), findsOneWidget);
    expect(find.text('Задача 1'), findsOneWidget);
    expect(find.text('Задача 2'), findsOneWidget);

    // Tap column chip to open popover type selector
    await tester.tap(find.text('(number)'));
    await tester.pumpAndSettle();

    // Verify type options are presented
    expect(find.text('Column: Время'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Select (Tags)'), findsOneWidget);

    // Select Text type
    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    // Verify column chip updated from (number) to (text)
    expect(find.text('(text)'), findsOneWidget);

    // Toggle to Raw CSV view
    await tester.tap(find.text('Raw CSV'));
    await tester.pumpAndSettle();

    // Toggle back to Table Preview
    await tester.tap(find.text('Table Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Задача 1'), findsOneWidget);

    // Tap import
    await tester.tap(find.text('Import as New Database Page'));
    await tester.pumpAndSettle();

    expect(importedPageId, isNotNull);
    final page = await repository.getPage(importedPageId!);
    expect(page, isNotNull);
  });
}
