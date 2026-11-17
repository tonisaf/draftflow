import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_query.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/database/database_grid_navigation.dart';
import 'package:notes_here/ui/editor/components/database/database_grid_selection.dart';
import 'package:notes_here/ui/editor/components/database/database_columns_header.dart';
import 'package:notes_here/ui/editor/components/database/database_row_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late ScrollController vertical, horizontal;
  late DatabaseGridSelectionController selection;
  late FocusNode before;
  late List<DatabaseRowData> rows;
  late List<DatabaseColumn> columns;
  late AppDatabase db;
  late NotesRepository repo;
  String? copied;
  int opened = 0;
  double? resized;
  setUp(() {
    vertical = ScrollController();
    horizontal = ScrollController();
    selection = DatabaseGridSelectionController();
    before = FocusNode();
    copied = null;
    opened = 0;
    resized = null;
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    columns = [
      for (var c = 0; c < 6; c++)
        DatabaseColumn(
          id: 'c$c',
          databaseId: 'd',
          name: 'Column $c',
          type: 'text',
          width: 120,
          orderKey: '$c',
          createdAt: DateTime(2026),
        ),
    ];
    rows = [
      for (var r = 0; r < 40; r++)
        DatabaseRowData(
          Page(id: 'r$r', title: 'Row $r', createdAt: DateTime(2026)),
          properties: {for (var c = 0; c < 6; c++) 'c$c': '$r:$c'},
        ),
    ];
  });
  tearDown(() async {
    vertical.dispose();
    horizontal.dispose();
    selection.dispose();
    before.dispose();
    await db.close();
  });
  Widget mount({bool realRows = false, String locale = 'en'}) => MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            focusNode: before,
            onPressed: before.requestFocus,
            child: const Text('Before'),
          ),
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 784,
                child: Column(
                  children: [
                    ColumnsHeaderRow(
                      selectionController: selection,
                      columns: columns,
                      columnWidths: const {},
                      headerBg: Colors.white,
                      borderColor: Colors.grey,
                      onSortChanged: (_, _) {},
                      onResize: (_, w) => resized = w,
                      onResizeEnd: (_, _) {},
                      onDeleteColumn: (_) {},
                      onAddColumn: () {},
                    ),
                    SizedBox(
                      height: 144,
                      child: DatabaseGridSelection(
                        key: const Key('grid'),
                        controller: selection,
                        columns: columns,
                        widths: const {},
                        rows: rows,
                        scrollController: vertical,
                        horizontalScrollController: horizontal,
                        child: ListView.builder(
                          controller: vertical,
                          itemExtent: 36,
                          itemCount: rows.length,
                          itemBuilder: (_, i) => realRows
                              ? DataRowView(
                                  key: ValueKey(rows[i].page.id),
                                  page: rows[i].page,
                                  properties: rows[i].properties,
                                  columns: columns,
                                  columnWidths: const {},
                                  borderColor: Colors.grey,
                                  isEven: i.isEven,
                                  repository: repo,
                                  onOpenPage: () => opened++,
                                  onUpdateTitle: (_) {},
                                  onPatchProperties: (_) {},
                                  onDeleteRow: () {},
                                )
                              : SizedBox(
                                  height: 36,
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 28),
                                      for (var c = 0; c < 6; c++)
                                        SizedBox(
                                          width: 120,
                                          child: Text('$i:$c'),
                                        ),
                                      const SizedBox(width: 36),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DatabaseSelectionStatus(controller: selection),
        ],
      ),
    ),
  );
  Future<void> key(
    WidgetTester t,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(key);
    if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester t, {
    bool realRows = false,
    String locale = 'en',
  }) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(mount(realRows: realRows, locale: locale));
    before.requestFocus();
    await t.pump();
    await key(t, LogicalKeyboardKey.tab);
    final gridFocus = t
        .widgetList<Focus>(find.byType(Focus))
        .firstWhere((f) => f.focusNode?.debugLabel == 'Database grid')
        .focusNode!;
    gridFocus.requestFocus();
    await t.pumpAndSettle();
  }

  Offset origin(WidgetTester t) =>
      t.getTopLeft(find.byType(DatabaseGridSelection));
  Future<void> frames(WidgetTester t, {int count = 5}) async {
    for (var i = 0; i < count; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  testWidgets(
    'stationary drag at bottom/right edges autoscrolls and updates selection; release stops',
    (t) async {
      await open(t);
      final start = origin(t);
      final gesture = await t.startGesture(start + const Offset(40, 18));
      await gesture.moveTo(start + const Offset(355, 142));
      await frames(t);
      expect(vertical.offset, greaterThan(0));
      expect(horizontal.offset, greaterThan(0));
      expect(selection.value!.rows, greaterThan(4));
      expect(selection.value!.columns, greaterThanOrEqualTo(3));
      await gesture.up();
      await t.pumpAndSettle();
      final v = vertical.offset, h = horizontal.offset;
      await t.pump(const Duration(seconds: 1));
      expect(vertical.offset, v);
      expect(horizontal.offset, h);
      await key(t, LogicalKeyboardKey.keyC, control: true);
      final range = selection.value!;
      expect(
        copied,
        databaseRangeTsv(
          columns,
          rows,
          range.firstRow,
          range.lastRow,
          range.firstColumn,
          range.lastColumn,
        ),
      );
      await finish(t);
    },
  );
  testWidgets('drag reverses at top/left and stops at scroll bounds', (
    t,
  ) async {
    await open(t);
    vertical.jumpTo(400);
    horizontal.jumpTo(240);
    await t.pump();
    final start = origin(t);
    final gesture = await t.startGesture(start + const Offset(300, 60));
    // The visible viewport starts at content x=240 after horizontal scrolling.
    await gesture.moveTo(Offset(1, start.dy + 1));
    await frames(t, count: 8);
    expect(vertical.offset, lessThan(400));
    expect(horizontal.offset, lessThan(240));
    vertical.jumpTo(0);
    horizontal.jumpTo(0);
    await frames(t, count: 2);
    expect(t.binding.transientCallbackCount, 0);
    await gesture.cancel();
    await t.pumpAndSettle();
    await finish(t);
  });
  testWidgets('cancel, filter change and disposal stop the ticker safely', (
    t,
  ) async {
    await open(t);
    var start = origin(t);
    var gesture = await t.startGesture(start + const Offset(40, 18));
    await gesture.moveTo(start + const Offset(355, 142));
    await frames(t);
    await gesture.cancel();
    await t.pumpAndSettle();
    final offset = vertical.offset;
    await t.pump(const Duration(seconds: 1));
    expect(vertical.offset, offset);
    start = origin(t);
    gesture = await t.startGesture(start + Offset(horizontal.offset + 40, 18));
    await gesture.moveTo(Offset(355, start.dy + 142));
    await frames(t);
    rows = rows.take(2).toList();
    await t.pumpWidget(mount());
    await t.pumpAndSettle();
    expect(selection.value, isNull);
    await gesture.cancel();
    await finish(t);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'gutter click and Shift-click select entire rows with correct dimensions and copy',
    (t) async {
      await open(t, realRows: true, locale: 'ru');
      final start = origin(t);
      await t.tapAt(start + const Offset(12, 18));
      await t.pumpAndSettle();
      expect(selection.value!.mode, DatabaseSelectionMode.rows);
      expect(selection.value!.cells, 6);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.tapAt(start + const Offset(12, 90));
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(selection.value!.rows, 3);
      expect(selection.value!.columns, 6);
      expect(find.text('3 × 6 · ячеек: 18'), findsOneWidget);
      await key(t, LogicalKeyboardKey.keyC, control: true);
      expect(copied, databaseRangeTsv(columns, rows, 0, 2, 0, 5));
      await key(t, LogicalKeyboardKey.escape);
      expect(
        find.byKey(const Key('database_selection_dimensions')),
        findsNothing,
      );
      await finish(t);
    },
  );
  testWidgets(
    'gutter row drag autoscrolls only vertically and double-click opens page',
    (t) async {
      await open(t, realRows: true);
      final start = origin(t);
      final gesture = await t.startGesture(start + const Offset(12, 18));
      await gesture.moveTo(Offset(355, start.dy + 142));
      await frames(t);
      expect(vertical.offset, greaterThan(0));
      expect(horizontal.offset, 0);
      expect(selection.value!.columns, 6);
      await gesture.up();
      await t.pumpAndSettle();
      vertical.jumpTo(0);
      await t.pump();
      final row = find.byKey(const ValueKey('database_select_row_r0'));
      await t.tap(row);
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(row);
      await t.pumpAndSettle();
      expect(opened, 1);
      await finish(t);
    },
  );
  testWidgets(
    'column glyph selects all loaded rows, Shift extends and corner selects page',
    (t) async {
      await open(t);
      await t.tap(find.byKey(const ValueKey('database_select_column_c0')));
      await t.pumpAndSettle();
      expect(selection.value!.rows, 40);
      expect(selection.value!.columns, 1);
      expect(selection.value!.mode, DatabaseSelectionMode.columns);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.tap(find.byKey(const ValueKey('database_select_column_c2')));
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pumpAndSettle();
      expect(selection.value!.columns, 3);
      expect(find.text('40 × 3 · cells: 120'), findsOneWidget);
      await key(t, LogicalKeyboardKey.keyC, control: true);
      expect(copied, databaseRangeTsv(columns, rows, 0, 39, 0, 2));
      await t.tap(find.byKey(const Key('database_select_all')));
      await t.pumpAndSettle();
      expect(selection.value!.cells, 240);
      await finish(t);
    },
  );
  testWidgets(
    'Shift+Space/Ctrl+Space preserve active row and resize handle remains separate',
    (t) async {
      await open(t);
      await key(t, LogicalKeyboardKey.arrowDown);
      await key(t, LogicalKeyboardKey.arrowRight);
      await key(t, LogicalKeyboardKey.space, shift: true);
      expect(selection.value!.firstRow, 1);
      expect(selection.value!.rows, 1);
      expect(selection.value!.columns, 6);
      await key(t, LogicalKeyboardKey.arrowDown, shift: true);
      expect(selection.value!.rows, 2);
      expect(selection.value!.columns, 6);
      await key(t, LogicalKeyboardKey.arrowUp, shift: true);
      expect(selection.value!.rows, 1);
      await key(t, LogicalKeyboardKey.space, control: true);
      expect(selection.value!.firstColumn, 1);
      expect(selection.value!.rows, 40);
      await key(t, LogicalKeyboardKey.arrowRight, shift: true);
      expect(selection.value!.columns, 2);
      expect(selection.value!.rows, 40);
      await key(t, LogicalKeyboardKey.arrowLeft, shift: true);
      expect(selection.value!.columns, 1);
      await key(t, LogicalKeyboardKey.arrowRight);
      expect(selection.value!.firstRow, 1);
      expect(selection.value!.firstColumn, 2);
      expect(selection.value!.cells, 1);
      final header = find.byType(ResizableColumnHeader).first;
      final rect = t.getRect(header);
      await t.dragFrom(
        Offset(rect.right - 2, rect.center.dy),
        const Offset(60, 0),
      );
      await t.pumpAndSettle();
      expect(resized, greaterThan(120));
      await finish(t);
    },
  );
  testWidgets(
    'focus loss hides dimensions and detaching a grid clears its controller',
    (t) async {
      await open(t);
      await key(t, LogicalKeyboardKey.space, control: true);
      expect(selection.value!.rows, 40);
      before.requestFocus();
      await t.pumpAndSettle();
      expect(selection.value, isNull);
      selection.selectColumn('c1');
      await t.pumpAndSettle();
      expect(selection.value!.columns, 1);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DatabaseSelectionStatus(controller: selection)),
        ),
      );
      await t.pumpAndSettle();
      expect(selection.value, isNull);
      expect(
        find.byKey(const Key('database_selection_dimensions')),
        findsNothing,
      );
      await finish(t);
    },
  );
}
