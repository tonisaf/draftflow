import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/services/database_cell_saves.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart'
    as cells;
import 'package:notes_here/ui/editor/components/database/database_grid_navigation.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late DatabaseCellSaves saves;
  final writes = <dynamic>[];
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    writes.clear();
    saves = DatabaseCellSaves((_, value) async {
      writes.add(value);
    });
  });
  tearDown(() => db.close());
  Widget cell(
    String type, {
    dynamic value,
    double width = 160,
    String row = 'r',
  }) => cells.DataCell(
    key: ValueKey('cell_$row'),
    column: DatabaseColumn(
      id: 'c',
      databaseId: 'd',
      name: 'Value',
      type: type,
      options: type == 'number' ? '{"format":"duration_hms"}' : null,
      width: width,
      orderKey: 'a',
      createdAt: DateTime(2026),
    ),
    width: width,
    borderColor: Colors.grey,
    rowId: row,
    saves: saves,
    pageTitle: type == 'title' ? value as String : 'Row',
    cellValue: value,
    repository: repo,
    onUpdateTitle: (_) {},
    onUpdateValue: (_) {},
    onOpenPage: () {},
  );
  Widget app(
    Widget body, {
    Brightness brightness = Brightness.light,
    bool font = false,
  }) => MaterialApp(
    theme: font
        ? buildTheme(brightness).copyWith(
            textTheme: buildTheme(brightness).textTheme
                .apply(fontFamily: 'Overlay preview'),
          )
        : buildTheme(brightness),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: body),
  );
  Finder getEditor() => find.byKey(const Key('expanded_database_cell'));
  Finder surface() => find.byKey(const Key('database_cell_editor_surface'));
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'title editor aligns full cell and text baseline ($brightness)',
      (tester) async {
        await tester.pumpWidget(
          app(
            Stack(
              children: [
                Positioned(
                  left: 80,
                  top: 100,
                  child: cell('title', value: 'Database Migration', width: 240),
                ),
              ],
            ),
            brightness: brightness,
          ),
        );
        final rect = tester.getRect(find.byType(cells.DataCell));
        final idle = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        final caret = idle.localToGlobal(
          idle.getLocalRectForCaret(const TextPosition(offset: 0)).topLeft,
        );
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(surface()), rect.topLeft);
        expect(tester.getSize(surface()).width, rect.width);
        expect(tester.getSize(surface()).height, greaterThanOrEqualTo(36));
        final active = tester
            .state<EditableTextState>(
              find.descendant(
                of: getEditor(),
                matching: find.byType(EditableText),
              ),
            )
            .renderEditable;
        final expanded = active.localToGlobal(
          active.getLocalRectForCaret(const TextPosition(offset: 0)).topLeft,
        );
        expect(expanded.dx, closeTo(caret.dx, 1));
        expect(expanded.dy, closeTo(caret.dy, 1));
        await tester.enterText(getEditor(), 'Не сохранять');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await finish(tester);
      },
    );
  }
  testWidgets('URL wraps fully in a wide editor anchored to its cell', (
    tester,
  ) async {
    final long =
        'https://jira.example.com:8443/browse/PROJECT-101?query=${List.filled(8, "long-query-value").join("-")}';
    final edit = DatabaseCellEditor();
    await tester.pumpWidget(
      app(
        Stack(
          children: [
            Positioned(
              left: 40,
              top: 100,
              child: SizedBox(
                width: 160,
                child: cells.UrlCellInput(
                  editor: edit,
                  initialValue: long,
                  onChanged: (v) => writes.add(v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    edit.open!();
    await tester.pumpAndSettle();
    expect(tester.getSize(surface()).width, UiLayout.cellUrlEditorMinWidth);
    expect(tester.widget<TextField>(getEditor()).controller!.text, long);
    final editable = tester
        .state<EditableTextState>(
          find.descendant(of: getEditor(), matching: find.byType(EditableText)),
        )
        .renderEditable;
    expect(editable.size.height, greaterThan(36));
    await tester.enterText(getEditor(), 'https://changed.example');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(writes, ['https://changed.example']);
    await finish(tester);
  });
  testWidgets(
    'duration shares anchored geometry, validates and preserves cancel/save',
    (tester) async {
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              Positioned(
                left: 80,
                top: 100,
                child: cell('number', value: 5400),
              ),
            ],
          ),
        ),
      );
      final rect = tester.getRect(find.byType(cells.DataCell));
      await tester.tap(find.text('01:30:00'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(surface()), rect.topLeft);
      expect(tester.getSize(surface()).width, 240);
      await tester.enterText(getEditor(), '32+32');
      await tester.pump();
      expect(
        find.byTooltip(
          'Формулы пока не поддерживаются. Введите готовое значение.',
        ),
        findsOneWidget,
      );
      expect(tester.getRect(find.byType(cells.DataCell)), rect);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.text('01:30:00'));
      await tester.pumpAndSettle();
      await tester.enterText(getEditor(), '01:30:01');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(writes, [5401]);
      await finish(tester);
    },
  );
  for (final horizontal in [false, true]) {
    testWidgets(
      'scroll closes and commits anchored editor (horizontal=$horizontal)',
      (tester) async {
        final scroll = ScrollController();
        await tester.pumpWidget(
          app(
            SizedBox(
              width: 300,
              height: 100,
              child: SingleChildScrollView(
                controller: scroll,
                scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
                child: SizedBox(
                  width: horizontal ? 900 : 300,
                  height: horizontal ? 100 : 900,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: cell('title', value: 'Original'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        await tester.enterText(getEditor(), 'Saved on scroll');
        scroll.jumpTo(36);
        await tester.pumpAndSettle();
        expect(getEditor(), findsNothing);
        expect(writes, ['Saved on scroll']);
        await finish(tester);
        scroll.dispose();
      },
    );
  }
  testWidgets(
    'resize closes editor and narrow viewport keeps the surface on screen',
    (tester) async {
      tester.view.physicalSize = const Size(300, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final edit = DatabaseCellEditor();
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              Positioned(
                left: 190,
                top: 100,
                child: SizedBox(
                  width: 100,
                  child: cells.UrlCellInput(
                    editor: edit,
                    initialValue: 'https://example.com',
                    onChanged: (v) => writes.add(v),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      edit.open!();
      await tester.pumpAndSettle();
      final bounds = tester.getRect(surface());
      expect(bounds.left, greaterThanOrEqualTo(8));
      expect(bounds.right, lessThanOrEqualTo(292));
      await tester.enterText(getEditor(), 'https://resized.example');
      tester.view.physicalSize = const Size(350, 450);
      await tester.pumpAndSettle();
      expect(getEditor(), findsNothing);
      expect(writes, ['https://resized.example']);
      await finish(tester);
    },
  );
  testWidgets(
    'nested overlay uses local coordinates and saves render previews',
    (tester) async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('Overlay preview')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await tester.runAsync(() => loader.load());
      }
      final preview = GlobalKey();
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: preview,
            child: Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 70,
                  width: 500,
                  height: 350,
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Stack(
                          children: [
                            Positioned(
                              left: 40,
                              top: 40,
                              child: cell(
                                'title',
                                value: 'Database Migration',
                                width: 240,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          font: font.existsSync(),
        ),
      );
      final rect = tester.getRect(find.byType(cells.DataCell));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(surface()), rect.topLeft);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(preview),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/logs').create(recursive: true);
        await File('build/logs/cell-overlay-alignment.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await finish(tester);
    },
  );
}
