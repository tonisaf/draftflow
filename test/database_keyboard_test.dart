import 'package:drift/drift.dart' as drift;
import 'package:notes_here/data/model/database_query.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/ui/editor/components/database/database_grid_selection.dart';
import 'package:notes_here/ui/editor/components/database/database_row_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late ScrollController vertical, horizontal;
  late FocusNode before, after;
  late DatabaseCellSaves saves;
  late List<DatabaseColumn> columns;
  late List<DatabaseRowData> rows;
  final writes = <(CellSaveKey, dynamic)>[];
  String? copied;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    vertical = ScrollController();
    horizontal = ScrollController();
    before = FocusNode();
    after = FocusNode();
    writes.clear();
    copied = null;
    saves = DatabaseCellSaves((key, value) async {
      writes.add((key, value));
    });
    columns = [
      for (final type in [
        'title',
        'text',
        'number',
        'url',
        'checkbox',
        'select',
        'date',
      ])
        DatabaseColumn(
          id: type,
          databaseId: 'd',
          name: type,
          type: type,
          width: 120,
          options: type == 'select'
              ? '[{"id":"a","label":"Alpha","color":4280391411}]'
              : null,
          orderKey: type,
          createdAt: DateTime(2026),
        ),
    ];
    rows = [
      for (var i = 0; i < 30; i++)
        DatabaseRowData(
          Page(id: '$i', title: 'Row $i', createdAt: DateTime(2026)),
          properties: {
            'text': 'Text $i',
            'number': i,
            'url': 'https://example.com',
            'checkbox': false,
          },
        ),
    ];
  });
  tearDown(() async {
    vertical.dispose();
    horizontal.dispose();
    before.dispose();
    after.dispose();
    await db.close();
  });
  Widget mount({bool empty = false}) => MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            focusNode: before,
            onPressed: () {},
            child: const Text('Before'),
          ),
          SizedBox(
            width: 360,
            height: 144,
            child: SingleChildScrollView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width:
                    DesktopUx.databaseGutterWidth +
                    columns.length * 120 +
                    DesktopUx.databaseActionWidth,
                child: DatabaseGridSelection(
                  saves: saves,
                  columns: columns,
                  widths: const {},
                  rows: empty ? [] : rows,
                  scrollController: vertical,
                  horizontalScrollController: horizontal,
                  child: ListView.builder(
                    controller: vertical,
                    itemExtent: 36,
                    itemCount: empty ? 0 : rows.length,
                    itemBuilder: (_, i) => DataRowView(
                      key: ValueKey(rows[i].page.id),
                      saves: saves,
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
            ),
          ),
          TextButton(
            focusNode: after,
            onPressed: after.requestFocus,
            child: const Text('After'),
          ),
        ],
      ),
    ),
  );
  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
    bool control = false,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  Future<void> enterGrid(WidgetTester tester) async {
    await tester.pumpWidget(mount());
    before.requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.tab);
    expect(find.byKey(const Key('database_range_selection')), findsOneWidget);
  }

  Future<String?> copy(WidgetTester tester) async {
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
    await key(tester, LogicalKeyboardKey.keyC, control: true);
    return copied;
  }

  testWidgets('arrows clamp, Shift extends a rectangle and Ctrl+C copies it', (
    tester,
  ) async {
    await enterGrid(tester);
    expect(await copy(tester), 'Row 0');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(await copy(tester), 'Row 0');
    await key(tester, LogicalKeyboardKey.arrowRight, shift: true);
    await key(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(await copy(tester), 'Row 0\tText 0\r\nRow 1\tText 1');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(await copy(tester), '1');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('Tab wraps rows and both boundaries leave the grid', (
    tester,
  ) async {
    rows = rows.take(2).toList();
    await enterGrid(tester);
    await key(tester, LogicalKeyboardKey.tab, shift: true);
    expect(before.hasPrimaryFocus, isTrue);
    await key(tester, LogicalKeyboardKey.tab);
    for (var i = 0; i < 7; i++) {
      await key(tester, LogicalKeyboardKey.tab);
    }
    expect(await copy(tester), 'Row 1');
    await key(tester, LogicalKeyboardKey.tab, shift: true);
    expect(await copy(tester), ''); // date in previous row
    for (var i = 0; i < 8; i++) {
      await key(tester, LogicalKeyboardKey.tab);
    }
    expect(after.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'F2 opens text, native selection stays local, Tab saves and Escape cancels',
    (tester) async {
      await enterGrid(tester);
      await key(tester, LogicalKeyboardKey.f2);
      final editor = find.byKey(const Key('expanded_database_cell'));
      expect(editor, findsOneWidget);
      await tester.enterText(editor, 'Edited title');
      await key(tester, LogicalKeyboardKey.keyA, control: true);
      expect(
        tester.widget<TextField>(editor).controller!.selection.baseOffset,
        0,
      );
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        tester.widget<TextField>(editor).controller!.selection.isCollapsed,
        isTrue,
      );
      await key(tester, LogicalKeyboardKey.tab);
      expect(editor, findsNothing);
      expect(writes.single.$2, 'Edited title');
      expect(await copy(tester), 'Text 0');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.enterText(editor, 'Discard me');
      await key(tester, LogicalKeyboardKey.escape);
      expect(writes, hasLength(1));
      expect(await copy(tester), 'Text 0');
      await key(tester, LogicalKeyboardKey.f2);
      await tester.enterText(editor, 'Multi\nline');
      await key(tester, LogicalKeyboardKey.enter, control: true);
      expect(writes.last.$2, 'Multi\nline');
      await key(tester, LogicalKeyboardKey.enter);
      await key(tester, LogicalKeyboardKey.tab, shift: true);
      expect(await copy(tester), 'Edited title');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'numeric Tab retains invalid draft, Escape cancels unsubmitted edits, URL Enter commits',
    (tester) async {
      await enterGrid(tester);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.enter);
      Finder input() => find.byKey(const Key('expanded_database_cell'));
      await tester.enterText(input(), '32+32');
      await key(tester, LogicalKeyboardKey.tab);
      expect(writes, isEmpty);
      const numberKey = (
        databaseId: 'd',
        rowId: '0',
        columnId: 'number',
        title: false,
      );
      expect(saves.entry(numberKey).phase, CellSavePhase.invalid);
      await key(tester, LogicalKeyboardKey.tab, shift: true);
      await key(tester, LogicalKeyboardKey.f2);
      await tester.enterText(input(), '999');
      await key(tester, LogicalKeyboardKey.escape);
      expect(writes, isEmpty);
      expect(saves.entry(numberKey).desired, '32+32');
      await key(tester, LogicalKeyboardKey.enter);
      await tester.enterText(input(), '12,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes.single.$2, 12.5);
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.f2);
      final urlInput = find.byWidgetPredicate(
        (w) => w is TextField && w.keyboardType == TextInputType.url,
      );
      await tester.enterText(urlInput, 'https://changed.example');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(writes.last.$2, 'https://changed.example');
      await key(tester, LogicalKeyboardKey.tab);
      await key(tester, LogicalKeyboardKey.enter);
      expect(writes.last.$2, isTrue);
      await key(tester, LogicalKeyboardKey.space);
      expect(writes.last.$2, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('keyboard reveals lazy rows and horizontally clipped cells', (
    tester,
  ) async {
    await enterGrid(tester);
    for (var i = 0; i < 20; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(vertical.offset, greaterThan(0));
    expect(find.byType(DataRowView).evaluate().length, lessThan(20));
    await key(tester, LogicalKeyboardKey.f2);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('expanded_database_cell')))
          .controller!
          .text,
      'Row 20',
    );
    await key(tester, LogicalKeyboardKey.escape);
    for (var i = 0; i < 5; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(horizontal.offset, greaterThan(0));
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.text('Alpha'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.escape);
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(await copy(tester), 'false');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('empty grid does not trap Tab or arrow keys', (tester) async {
    await tester.pumpWidget(mount(empty: true));
    before.requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.tab);
    expect(after.hasPrimaryFocus, isTrue);
    await key(tester, LogicalKeyboardKey.f2);
    await key(tester, LogicalKeyboardKey.tab, shift: true);
    expect(before.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'date editor returns focus and outside clicks keep their destination',
    (tester) async {
      await enterGrid(tester);
      for (var i = 0; i < 6; i++) {
        await key(tester, LogicalKeyboardKey.arrowRight);
      }
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(DatePickerDialog), findsNothing);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(await copy(tester), 'false');
      for (var i = 0; i < 4; i++) {
        await key(tester, LogicalKeyboardKey.arrowLeft);
      }
      await key(tester, LogicalKeyboardKey.enter);
      await tester.enterText(
        find.byKey(const Key('expanded_database_cell')),
        'Outside save',
      );
      await tester.tap(find.text('After'));
      await tester.pumpAndSettle();
      expect(after.hasPrimaryFocus, isTrue);
      expect(writes.last.$2, 'Outside save');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'row filtering clears obsolete coordinates before the next edit',
    (tester) async {
      await enterGrid(tester);
      for (var i = 0; i < 10; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      rows = rows.take(1).toList();
      await tester.pumpWidget(mount());
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.enter);
      expect(find.byKey(const Key('expanded_database_cell')), findsNothing);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.enter);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('expanded_database_cell')))
            .controller!
            .text,
        'Row 0',
      );
      await key(tester, LogicalKeyboardKey.escape);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'duration picker opened from expanded editor returns to keyboard grid',
    (tester) async {
      columns[2] = columns[2].copyWith(options: const drift.Value('{"format":"duration_hms"}'));
      await enterGrid(tester);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.tap(find.byKey(const ValueKey('open_duration_picker_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('duration_mins_input')),
        '5',
      );
      await tester.tap(find.byKey(const ValueKey('apply_duration_btn')));
      await tester.pumpAndSettle();
      expect(writes.last.$2, 300);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(await copy(tester), 'Text 0');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
