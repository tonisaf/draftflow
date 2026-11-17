import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/services/database_range_edits.dart';
import 'package:notes_here/ui/editor/components/database/database_grid_selection.dart';
import 'package:notes_here/ui/editor/components/database/database_row_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late DatabaseRangeEdits history;
  late String database, number, first, second;
  late List<DatabaseColumn> columns;
  late List<DatabaseRowData> rows;
  late ScrollController scroll;
  late FocusNode before;
  String? clipboard, copied;
  Completer<void>? clipboardGate;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    history = DatabaseRangeEdits.forRepository(repo);
    database = await repo.createDatabase();
    number = await repo.addColumn(database, name: 'Amount', type: 'number');
    first = await repo.createDatabaseRow(
      database,
      title: 'First',
      properties: {number: 1},
    );
    second = await repo.createDatabaseRow(
      database,
      title: 'Second',
      properties: {number: 2},
    );
    final all = await repo.getColumns(database);
    columns = [
      all.firstWhere((c) => c.type == 'title').copyWith(width: 160),
      all.firstWhere((c) => c.id == number).copyWith(width: 160),
    ];
    rows = [
      DatabaseRowData((await repo.getPage(first))!),
      DatabaseRowData((await repo.getPage(second))!),
    ];
    scroll = ScrollController();
    before = FocusNode();
    clipboard = null;
    copied = null;
    clipboardGate = null;
  });
  tearDown(() async {
    scroll.dispose();
    before.dispose();
    await db.close();
  });
  Widget mount({String locale = 'ru', bool empty = false}) => MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [
          TextButton(
            focusNode: before,
            onPressed: before.requestFocus,
            child: const Text('Before'),
          ),
          SizedBox(
            width: 384,
            height: 72,
            child: DatabaseGridSelection(
              columns: columns,
              widths: const {},
              rows: empty ? [] : rows,
              scrollController: scroll,
              saves: history.saves,
              rangeEdits: history,
              child: ListView.builder(
                controller: scroll,
                itemExtent: 36,
                itemCount: empty ? 0 : rows.length,
                itemBuilder: (_, i) => DataRowView(
                  key: ValueKey(rows[i].page.id),
                  saves: history.saves,
                  page: rows[i].page,
                  properties: rows[i].properties,
                  columns: columns,
                  columnWidths: const {},
                  borderColor: Colors.grey,
                  isEven: i.isEven,
                  repository: repo,
                  onOpenPage: () {},
                  onUpdateTitle: (_) {},
                  onPatchProperties: (_) {},
                  onDeleteRow: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    if (clipboardGate != null && !clipboardGate!.isCompleted) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(WidgetTester tester, {String locale = 'ru'}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          if (clipboardGate != null) await clipboardGate!.future;
          return {'text': clipboard};
        }
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
    await tester.pumpWidget(mount(locale: locale));
    before.requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.tab);
  }

  Future<dynamic> value(String row) async =>
      jsonDecode((await repo.getPage(row))!.properties!)[number];
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Ctrl+V pastes a typed rectangle, Ctrl+Z restores all, Ctrl+Y redoes it',
    (tester) async {
      await open(tester);
      clipboard = 'New first\t12,5\r\nNew second\t20\r\n';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(await value(first), 12.5);
      expect((await repo.getPage(second))!.title, 'New second');
      expect(find.text('Вставлено ячеек: 4'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('database_range_selection'))),
        const Size(320, 72),
      );
      await key(tester, LogicalKeyboardKey.keyC, control: true);
      expect(copied, 'New first\t12.5\r\nNew second\t20');
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(await value(first), 1);
      expect((await repo.getPage(second))!.title, 'Second');
      await key(tester, LogicalKeyboardKey.keyY, control: true);
      expect(await value(first), 12.5);
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      await key(tester, LogicalKeyboardKey.keyZ, control: true, shift: true);
      expect(await value(second), 20);
      await dispose(tester);
    },
  );
  testWidgets('invalid cell explains row and reason without partial writes', (
    tester,
  ) async {
    await open(tester);
    clipboard = 'Changed\t10\nOther\t32+32';
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(find.text('Диапазон не изменён'), findsOneWidget);
    expect(find.textContaining('Строка 2, Amount:'), findsOneWidget);
    expect(
      find.textContaining('Формулы пока не поддерживаются'),
      findsOneWidget,
    );
    expect(await value(first), 1);
    expect((await repo.getPage(first))!.title, 'First');
    expect(history.canUndo(database), isFalse);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    clipboard = 'Changed\t10';
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(await value(first), 10);
    await dispose(tester);
  });
  testWidgets(
    'one value fills selected cells and snackbar undoes the complete fill',
    (tester) async {
      await open(tester, locale: 'en');
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowDown, shift: true);
      clipboard = '7';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(await value(first), 7);
      expect(await value(second), 7);
      await tester.tap(find.text('Undo paste'));
      await tester.pumpAndSettle();
      expect(await value(first), 1);
      expect(await value(second), 2);
      await tester.tap(find.text('Redo paste'));
      await tester.pumpAndSettle();
      expect(await value(second), 7);
      await dispose(tester);
    },
  );
  testWidgets(
    'undo conflict keeps all pasted cells and shows a localized explanation',
    (tester) async {
      await open(tester);
      clipboard = 'Changed\t10\nOther\t20';
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      await repo.patchRowProperties(second, {number: 99});
      await key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(
        find.textContaining('Ячейки или настройки колонок изменились'),
        findsOneWidget,
      );
      expect(await value(first), 10);
      expect(await value(second), 99);
      expect((await repo.getPage(first))!.title, 'Changed');
      await dispose(tester);
    },
  );
  testWidgets(
    'paste is canceled if the user moves while the clipboard is being read',
    (tester) async {
      await open(tester);
      clipboard = 'Changed';
      clipboardGate = Completer<void>();
      await key(tester, LogicalKeyboardKey.keyV, control: true);
      await key(tester, LogicalKeyboardKey.arrowDown);
      clipboardGate!.complete();
      await tester.pumpAndSettle();
      expect((await repo.getPage(first))!.title, 'First');
      expect((await repo.getPage(second))!.title, 'Second');
      expect(history.canUndo(database), isFalse);
      await dispose(tester);
    },
  );
  testWidgets('text editing owns native paste and undo instead of the grid', (
    tester,
  ) async {
    await open(tester);
    clipboard = 'Inline text';
    await key(tester, LogicalKeyboardKey.enter);
    final editor = find.byKey(const Key('expanded_database_cell'));
    await key(tester, LogicalKeyboardKey.keyA, control: true);
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(tester.widget<TextField>(editor).controller!.text, 'Inline text');
    expect((await repo.getPage(first))!.title, 'First');
    expect(history.canUndo(database), isFalse);
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(history.canUndo(database), isFalse);
    await key(tester, LogicalKeyboardKey.escape);
    await dispose(tester);
  });
  testWidgets('a matching but unsaved draft blocks the entire range', (
    tester,
  ) async {
    await open(tester);
    final entry = history.saves.entry((
      databaseId: database,
      rowId: first,
      columnId: number,
      title: false,
    ));
    entry.desired = 10;
    entry.hasDraft = true;
    entry.phase = CellSavePhase.failed;
    entry.submitted = true;
    clipboard = 'Changed\t10';
    await key(tester, LogicalKeyboardKey.keyV, control: true);
    expect(find.textContaining('черновики в целевых ячейках'), findsOneWidget);
    expect((await repo.getPage(first))!.title, 'First');
    expect(await value(first), 1);
    expect(entry.desired, 10);
    expect(history.canUndo(database), isFalse);
    await dispose(tester);
  });
}
