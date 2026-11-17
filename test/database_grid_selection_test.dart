import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/ui/editor/components/database/database_grid_selection.dart';
import 'package:notes_here/ui/editor/components/database/expanded_cell_editor.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  testWidgets('range copy works inside the document editor', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NotesRepository(db);
    final id = (await tester.runAsync(() async {
      final id = await repo.createDatabase(title: 'Selection');
      await repo.createDatabaseRow(id, title: 'First');
      await repo.createDatabaseRow(id, title: 'Second');
      return id;
    }))!;
    final state = EditorState(
      document: Document(
        root: pageNode(children: [databaseBlockNode(databaseId: id)]),
      ),
    );
    String? copied;
    String? pasted;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') return {'text': pasted};
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: state,
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
    final viewport = find.byKey(const Key('database_rows_viewport'));
    final origin = tester.getTopLeft(viewport);
    final gesture = await tester.startGesture(origin + const Offset(40, 18));
    await gesture.moveTo(origin + const Offset(300, 54));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expanded_database_cell')), findsNothing);
    expect(find.byKey(const Key('database_range_selection')), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, 'First\t\r\nSecond\t');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(origin + const Offset(40, 18));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expanded_database_cell')), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(origin + const Offset(300, 54));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expanded_database_cell')), findsNothing);
    expect(find.byKey(const Key('database_range_selection')), findsOneWidget);
    copied = null;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, 'First\t\r\nSecond\t');

    // Keyboard commands must remain owned by the grid inside AppFlowy.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    final keyboardEditor = find.byKey(const Key('expanded_database_cell'));
    expect(tester.widget<TextField>(keyboardEditor).controller!.text, 'Second');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(keyboardEditor).controller!.text, 'First');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    pasted = 'Pasted first\t\r\nPasted second\t';
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect((await repo.queryDatabaseRows(id)).rows.map((r) => r.page.title), [
      'Pasted first',
      'Pasted second',
    ]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect((await repo.queryDatabaseRows(id)).rows.map((r) => r.page.title), [
      'First',
      'Second',
    ]);

    final allColumns = await repo.getColumns(id);
    await tester.tap(
      find.byKey(ValueKey('database_select_column_${allColumns.first.id}')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, 'First\r\nSecond');
    expect(find.text('2 × 1 · cells: 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await tester.pumpAndSettle();
  });
  final columns = [
    for (final type in ['title', 'text'])
      DatabaseColumn(
        id: type,
        databaseId: 'd',
        name: type,
        type: type,
        width: 120,
        orderKey: type,
        createdAt: DateTime(2026),
      ),
  ];
  final rows = [
    for (var i = 0; i < 2; i++)
      DatabaseRowData(
        Page(id: '$i', title: 'Row $i', createdAt: DateTime(2026)),
        properties: {'text': i == 0 ? 'two\nlines' : 'a\tb "c"'},
      ),
  ];
  test('TSV preserves multiline text, tabs, quotes and reverse selection', () {
    expect(
      databaseRangeTsv(columns, rows, 1, 0, 1, 0),
      'Row 0\t"two\nlines"\r\nRow 1\t"a\tb ""c"""',
    );
  });
  testWidgets('drag selects rectangle and Ctrl+C copies the selected cells', (
    tester,
  ) async {
    final scroll = ScrollController();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 268,
              height: 72,
              child: DatabaseGridSelection(
                columns: columns,
                widths: const {},
                rows: rows,
                scrollController: scroll,
                child: ListView(
                  controller: scroll,
                  children: [
                    for (final row in rows)
                      SizedBox(height: 36, child: Text(row.page.title)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final drag = await tester.startGesture(const Offset(40, 18));
    await drag.moveTo(const Offset(180, 54));
    await drag.up();
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('database_range_selection'))),
      const Size(240, 72),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, databaseRangeTsv(columns, rows, 0, 1, 0, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('database_range_selection')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
  testWidgets(
    'expanded editor selects multiline text, saves outside and cancels Escape',
    (tester) async {
      String? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showExpandedCellEditor(context, 'one\ntwo');
                },
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      final editor = find.byKey(const Key('expanded_database_cell'));
      expect(tester.widget<TextField>(editor).maxLines, isNull);
      final start = tester.getTopLeft(editor) + const Offset(9, 12);
      final textDrag = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await textDrag.moveTo(start + const Offset(28, 0));
      await textDrag.up();
      await tester.pump();
      expect(
        tester.widget<TextField>(editor).controller!.selection.isCollapsed,
        isFalse,
      );

      await tester.enterText(editor, 'changed\ntext');
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(saved, 'changed\ntext');
      saved = 'unchanged';
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.enterText(editor, 'discard');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(saved, isNull);
    },
  );
}
