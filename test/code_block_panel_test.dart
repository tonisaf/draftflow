import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart' show AppDatabase;
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/editor/components/page_block_reorder.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  const sql =
      "SELECT pid, usename, application_name, client_addr, state, query\nFROM pg_stat_activity\nWHERE datname = 'cm7';";
  late EditorState editor;
  late Node code;
  setUp(() {
    code = codeBlockNode(language: 'sql', delta: Delta()..insert(sql));
    editor = EditorState(
      document: Document(root: pageNode(children: [code])),
    );
  });
  tearDown(() {
    if (!editor.isDisposed) editor.dispose();
  });

  Widget app({
    double width = 700,
    bool editable = true,
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    theme: buildTheme(brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: AppFlowyEditor(
          editable: editable,
          editorState: editor,
          editorStyle: EditorStyle.desktop(padding: EdgeInsets.zero),
          blockComponentBuilders: {
            ...standardBlockComponentBuilderMap,
            codeBlockType: CodeBlockComponentBuilder(),
          },
          commandShortcutEvents: [
            codeBlockPasteCommand,
            ...standardCommandShortcutEvents,
          ],
        ),
      ),
    ),
  );
  Finder title() => find.byKey(const Key('code_block_title'));
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  Future<void> hover(WidgetTester t) async {
    final gesture = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(t.getCenter(find.byType(CodeBlockComponentWidget).first));
    await t.pumpAndSettle();
  }

  testWidgets('legacy blocks get a blank title; header never overlaps code', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(t.widget<TextField>(title()).controller!.text, '');
    expect(find.text('Block name'), findsOneWidget);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    final header = t.getRect(find.byKey(const Key('code_block_header')));
    final rich = t.getRect(find.byType(AppFlowyRichText).first);
    expect(rich.top, greaterThanOrEqualTo(header.bottom + 10));
    final before = t.getSize(find.byType(CodeBlockComponentWidget));
    await t.enterText(title(), 'Active connections');
    await t.pumpAndSettle();
    expect(code.attributes['title'], 'Active connections');
    expect(code.delta!.toPlainText(), sql);
    expect(t.getSize(find.byType(CodeBlockComponentWidget)), before);
    await finish(t);
  });

  testWidgets(
    'typing and native paste edit only the title; document undo restores it',
    (t) async {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': ' extra'};
          return null;
        },
      );
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      editor.selection = Selection.collapsed(Position(path: [0], offset: 4));
      await t.enterText(title(), 'Connections');
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyV);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(code.attributes['title'], 'Connections extra');
      expect(code.delta!.toPlainText(), sql);
      expect(editor.document.root.children.length, 1);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      editor.undoManager.undo();
      await t.pumpAndSettle();
      expect(code.attributes['title'], isNot('Connections extra'));
      expect(
        t.widget<TextField>(title()).controller!.text,
        code.attributes['title'] ?? '',
      );
      expect(code.delta!.toPlainText(), sql);
      await finish(t);
    },
  );

  testWidgets(
    'copy excludes title and title survives language changes, fold and move undo',
    (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.enterText(title(), 'Active connections');
      await t.pumpAndSettle();
      await hover(t);
      await t.tap(find.byTooltip('Copy code'));
      await t.pumpAndSettle(const Duration(milliseconds: 100));
      expect(copied, sql);
      await t.pump(const Duration(milliseconds: 1600));
      await t.tap(find.text('SQL'));
      await t.pumpAndSettle();
      await t.tap(find.text('Plain Text').last);
      await t.pumpAndSettle();
      expect(code.attributes['title'], 'Active connections');
      final expanded = t.getSize(find.byType(CodeBlockComponentWidget)).height;
      await t.tap(find.byTooltip('Collapse code'));
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byType(CodeBlockComponentWidget)).height,
        lessThan(expanded - 20),
      );
      expect(
        t.widget<TextField>(title()).controller!.text,
        'Active connections',
      );
      await t.tap(find.byTooltip('Expand code'));
      await t.pumpAndSettle();
      final other = paragraphNode(text: 'Other');
      await editor.apply(editor.transaction..insertNode([1], other));
      final target = editor.document.root.children.last;
      await movePageBlock(editor, code, target, after: true);
      await t.pumpAndSettle();
      expect(
        editor.document.root.children.last.attributes['title'],
        'Active connections',
      );
      editor.undoManager.undo();
      await t.pumpAndSettle();
      expect(
        editor.document.root.children.first.attributes['title'],
        'Active connections',
      );
      await finish(t);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'narrow header and large text fit without overlapping actions $brightness',
      (t) async {
        await t.pumpWidget(app(width: 240, scale: 1.8, brightness: brightness));
        await t.pumpAndSettle();
        await t.enterText(
          title(),
          'A very long title for this saved SQL query',
        );
        await t.pumpAndSettle();
        final header = t.getRect(find.byKey(const Key('code_block_header')));
        final name = t.getRect(title());
        final copy = t.getRect(find.byTooltip('Copy code'));
        expect(copy.top, greaterThanOrEqualTo(name.bottom));
        expect(copy.right, lessThanOrEqualTo(header.right));
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets(
    'read-only blocks keep copy available but disable title, language and fold edits',
    (t) async {
      await t.pumpWidget(app(editable: false));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(title()).readOnly, isTrue);
      expect(find.byKey(const Key('code_more_actions')), findsNothing);
      expect(
        t
            .widget<IconButton>(find.byKey(const Key('code_fold_button')))
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
      expect(find.byTooltip('Copy code'), findsOneWidget);
      expect(code.attributes['title'], isNull);
      await finish(t);
    },
  );

  testWidgets('production title persists on reopen with native-font preview', (
    t,
  ) async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Panel preview')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await t.runAsync(() => loader.load());
    }
    final mono = File('C:/Windows/Fonts/consola.ttf');
    if (mono.existsSync()) {
      final loader = FontLoader('Consolas')
        ..addFont(Future.value(ByteData.sublistView(mono.readAsBytesSync())));
      await t.runAsync(() => loader.load());
    }
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await t.runAsync(() => icons.load());
    final db = AppDatabase(NativeDatabase.memory());
    final repo = NotesRepository(db);
    final page = await repo.createPage(title: 'Проекты');
    await repo.savePageNodes(page, [
      codeBlockNode(language: 'sql', delta: Delta()..insert(sql)),
      paragraphNode(text: 'Посмотреть все активные подключения к базе cm7'),
    ]);
    final preview = GlobalKey();
    Widget production() => RepaintBoundary(
      key: preview,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: font.existsSync()
            ? buildTheme(Brightness.light).copyWith(
                textTheme: buildTheme(Brightness.light).textTheme
                    .apply(fontFamily: 'Panel preview'),
              )
            : buildTheme(Brightness.light),
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PageEditorView(
            repository: repo,
            pageId: page,
            title: 'Проекты',
          ),
        ),
      ),
    );
    await t.pumpWidget(production());
    await t.pumpAndSettle();
    await t.enterText(title(), 'Активные подключения');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(preview));
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory('build/logs').create(recursive: true);
      await File('build/logs/code-panel-preview.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
    await finish(t);
    final stored = (await repo.loadPageSnapshot(page)).document;
    expect(
      stored.root.children.first.attributes['title'],
      'Активные подключения',
    );
    expect(stored.root.children.first.delta!.toPlainText(), sql);
    await t.pumpWidget(production());
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(title()).controller!.text,
      'Активные подключения',
    );
    await finish(t);
    stored.dispose();
    await db.close();
    expect(t.takeException(), isNull);
  });
}
