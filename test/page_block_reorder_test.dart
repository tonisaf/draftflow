import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:drift/native.dart';
import 'package:notes_here/data/db/app_database.dart' show AppDatabase;
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/editor/components/code_block_component.dart';
import 'package:notes_here/ui/editor/components/notes_paragraph_component.dart';
import 'package:notes_here/ui/editor/components/page_block_reorder.dart';
import 'package:notes_here/ui/editor/components/smooth_page_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late EditorState editor;
  late Node code, text, last;
  setUp(() {
    code = codeBlockNode(
      language: 'sql',
      collapsed: false,
      delta: Delta()..insert('SELECT * FROM projects;'),
    );
    text = paragraphNode(text: 'Description above the query');
    last = paragraphNode(text: 'Last block');
    editor = EditorState(
      document: Document(root: pageNode(children: [code, text, last])),
    );
  });
  tearDown(() {
    if (!editor.isDisposed) editor.dispose();
  });
  List<String> order() =>
      editor.document.root.children.map((node) => node.id).toList();

  test(
    'moving down/up preserves code metadata, selection and one-step undo/redo',
    () async {
      editor.selection = Selection.collapsed(Position(path: [0], offset: 7));
      expect(await movePageBlock(editor, code, text, after: true), isTrue);
      expect(order(), [text.id, code.id, last.id]);
      expect(editor.document.root.children[1], same(code));
      expect(code.attributes['language'], 'sql');
      expect(code.delta!.toPlainText(), 'SELECT * FROM projects;');
      expect(editor.selection!.start.path, [1]);
      expect(editor.selection!.start.offset, 7);
      editor.undoManager.undo();
      expect(order(), [code.id, text.id, last.id]);
      editor.undoManager.redo();
      expect(order(), [text.id, code.id, last.id]);
      final moved = editor.document.root.children[1];
      expect(
        await movePageBlock(
          editor,
          moved,
          editor.document.root.children[0],
          after: false,
        ),
        isTrue,
      );
      expect(order(), [code.id, text.id, last.id]);
    },
  );

  test(
    'moving nested lists and database nodes retains descendants and references',
    () async {
      final list = Node(
        type: 'bulleted_list',
        attributes: {'delta': (Delta()..insert('Parent')).toJson()},
        children: [paragraphNode(text: 'Nested child')],
      );
      final database = Node(
        type: 'database',
        attributes: {'databaseId': 'existing-db'},
      );
      editor.dispose();
      text = paragraphNode(text: 'Description above the query');
      editor = EditorState(
        document: Document(root: pageNode(children: [list, database, text])),
      );
      editor.selection = Selection.collapsed(Position(path: [0, 0], offset: 3));
      expect(await movePageBlock(editor, list, text, after: true), isTrue);
      expect(
        editor.document.root.children.last.children.single.delta!.toPlainText(),
        'Nested child',
      );
      expect(
        editor.document.root.children.first.attributes['databaseId'],
        'existing-db',
      );
      expect(editor.selection!.start.path, [2, 0]);
      editor.undoManager.undo();
      expect(editor.document.root.children.first.id, list.id);
    },
  );

  test('moves are isolated from typing and invalid/stale/no-op targets do not modify history', () async {
    final typing = editor.transaction..insertText(text, 0, 'New ');
    await editor.apply(typing);
    await movePageBlock(editor, code, text, after: true);
    editor.undoManager.undo();
    expect(order(), [code.id, text.id, last.id]);
    expect(
      editor.document.root.children[1].delta!.toPlainText(),
      startsWith('New '),
    );
    editor.undoManager.undo();
    expect(
      editor.document.root.children[1].delta!.toPlainText(),
      'Description above the query',
    );
    final nodes = editor.document.root.children;
    expect(
      await movePageBlock(editor, nodes[0], nodes[1], after: false),
      isFalse,
    );
    expect(
      await movePageBlock(editor, nodes[0], nodes[0], after: true),
      isFalse,
    );
    expect(
      await movePageBlock(editor, paragraphNode(), nodes[0], after: false),
      isFalse,
    );
    editor.editable = false;
    expect(
      await movePageBlock(editor, nodes[0], nodes[1], after: true),
      isFalse,
    );
  });

  Widget app({
    bool enabled = true,
    Brightness brightness = Brightness.light,
    bool reduced = false,
  }) => MaterialApp(
    theme: buildTheme(brightness),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Scaffold(
      body: AppFlowyEditor(
        editorState: editor,
        editorStyle: EditorStyle.desktop(
          maxWidth: 600,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        ),
        blockComponentBuilders: {
          ...standardBlockComponentBuilderMap,
          PageBlockKeys.type: SmoothPageBlockComponentBuilder(
            enableBlockReorder: enabled,
          ),
          'paragraph': NotesParagraphBlockComponentBuilder(),
          codeBlockType: CodeBlockComponentBuilder(),
        },
      ),
    ),
  );

  Finder frame(Node node) => find.byWidgetPredicate(
    (w) => w is PageBlockReorderFrame && w.node.id == node.id,
  );
  Finder handle(Node node) =>
      find.byKey(ValueKey('page_block_handle_${node.id}'));
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'drag code below text shows insertion line and preserves text layout $brightness',
      (t) async {
        await t.pumpWidget(app(brightness: brightness));
        await t.pumpAndSettle();
        final original = t.getRect(
          find.byType(NotesParagraphBlockComponentWidget).first,
        );
        final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(t.getCenter(frame(code)));
        await t.pumpAndSettle();
        expect(
          t.getRect(find.byType(NotesParagraphBlockComponentWidget).first),
          original,
        );
        final drag = await t.startGesture(
          t.getCenter(handle(code)),
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveBy(const Offset(5, 20));
        await t.pump();
        final target = t.getRect(frame(text));
        await drag.moveTo(Offset(target.center.dx, target.bottom - 3));
        await t.pump();
        expect(
          find.byKey(const Key('page_block_drag_preview')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('page_block_drop_line')), findsOneWidget);
        expect(
          t.getRect(find.byKey(const Key('page_block_drop_line'))).bottom,
          closeTo(target.bottom - 1, 0.1),
        );
        await drag.up();
        await t.pumpAndSettle();
        expect(order(), [text.id, code.id, last.id]);
        expect(find.byKey(const Key('page_block_drag_preview')), findsNothing);
        expect(find.byKey(const Key('page_block_drop_line')), findsNothing);
        editor.undoManager.undo();
        await t.pumpAndSettle();
        expect(order(), [code.id, text.id, last.id]);
        await mouse.removePointer();
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }

  testWidgets('handle menu moves block and Ctrl+Z restores its order', (
    t,
  ) async {
    await t.pumpWidget(app(reduced: true));
    await t.pumpAndSettle();
    await t.tap(handle(code));
    await t.pumpAndSettle();
    expect(find.text('Переместить выше'), findsNothing);
    await t.tap(find.text('Переместить ниже'));
    await t.pumpAndSettle();
    expect(order(), [text.id, code.id, last.id]);
    final modifier = Platform.isMacOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await t.sendKeyDownEvent(modifier);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(modifier);
    await t.pumpAndSettle();
    expect(order(), [code.id, text.id, last.id]);
    expect(t.takeException(), isNull);
    await finish(t);
  });

  testWidgets('disabled handles and cancelled drop never reorder blocks', (
    t,
  ) async {
    await t.pumpWidget(app(enabled: false));
    await t.pumpAndSettle();
    expect(find.byType(PageBlockReorderFrame), findsNothing);
    await finish(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final drag = await t.startGesture(
      t.getCenter(handle(code)),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveTo(const Offset(780, 550));
    await t.pump();
    await drag.cancel();
    await t.pumpAndSettle();
    expect(order(), [code.id, text.id, last.id]);
    expect(find.byKey(const Key('page_block_drag_preview')), findsNothing);
    await finish(t);
  });

  testWidgets(
    'production page saves the new order and reopens with code settings intact',
    (t) async {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('Block preview')
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
      final preview = GlobalKey();
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final page = await repo.createPage(title: 'Block order');
      await repo.savePageNodes(page, [
        codeBlockNode(
          language: 'sql',
          collapsed: false,
          delta: Delta()..insert('SELECT * FROM projects;'),
        ),
        paragraphNode(text: 'Description above the query'),
      ]);
      Widget production() => RepaintBoundary(
        key: preview,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: font.existsSync()
              ? buildTheme(Brightness.light).copyWith(
                  textTheme: buildTheme(Brightness.light).textTheme
                      .apply(fontFamily: 'Block preview'),
                )
              : buildTheme(Brightness.light),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PageEditorView(
              repository: repo,
              pageId: page,
              title: 'Block order',
            ),
          ),
        ),
      );
      await t.pumpWidget(production());
      await t.pumpAndSettle();
      final live = t
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      await t.tap(
        find.byKey(
          ValueKey('page_block_handle_${live.document.root.children.first.id}'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Переместить ниже'));
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(t.getCenter(find.byType(CodeBlockComponentWidget)));
      await t.pumpAndSettle();
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(preview),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await Directory('build/logs').create(recursive: true);
        await File('build/logs/block-reorder-preview.png')
            .writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
      await mouse.removePointer();
      await finish(t);
      final stored = (await repo.loadPageSnapshot(page)).document;
      expect(
        stored.root.children.first.delta!.toPlainText(),
        'Description above the query',
      );
      expect(stored.root.children.last.attributes['language'], 'sql');
      await t.pumpWidget(production());
      await t.pumpAndSettle();
      final reopened = t
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      expect(
        reopened.document.root.children.first.delta!.toPlainText(),
        'Description above the query',
      );
      expect(
        reopened.document.root.children.last.delta!.toPlainText(),
        'SELECT * FROM projects;',
      );
      await finish(t);
      stored.dispose();
      await db.close();
      expect(t.takeException(), isNull);
    },
  );

  test('blockHandleTopOffset aligns headings, quotes, code, and paragraphs', () {
    final h1First = headingNode(level: 1, text: 'First');
    final h1Later = headingNode(level: 1, text: 'Second');
    final h2Later = headingNode(level: 2, text: 'Sub');
    final h3Later = headingNode(level: 3, text: 'Subsub');
    final body = paragraphNode(text: 'Text');
    final doc = Document(
      root: pageNode(children: [h1First, body, h1Later, h2Later, h3Later]),
    );
    expect(doc.root.children.length, 5);

    expect(blockHandleTopOffset(h1First), equals(UiSpace.s6 + UiSpace.s2));
    expect(blockHandleTopOffset(h1Later), equals(UiSpace.s24 + UiSpace.s2));
    expect(blockHandleTopOffset(h2Later), equals(UiSpace.s18));
    expect(blockHandleTopOffset(h3Later), equals(UiSpace.s11_5));
    expect(blockHandleTopOffset(body), equals(-UiSpace.s1));
    expect(blockHandleTopOffset(code), equals(UiSpace.s8));
  });

  test('duplicatePageBlock and deletePageBlock clone fresh IDs and undo cleanly',
      () async {
    final nestedList = bulletedListNode(
      text: 'Parent',
      children: [bulletedListNode(text: 'Child')],
    );
    final singleEditor = EditorState(
      document: Document(root: pageNode(children: [nestedList])),
    );

    final clone = await duplicatePageBlock(singleEditor, nestedList);
    expect(clone, isNotNull);
    expect(singleEditor.document.root.children.length, 2);
    expect(clone!.id, isNot(equals(nestedList.id)));
    expect(clone.children.single.id, isNot(equals(nestedList.children.single.id)));
    expect(clone.children.single.delta!.toPlainText(), equals('Child'));

    singleEditor.undoManager.undo();
    expect(singleEditor.document.root.children.length, 1);

    // Deleting the sole remaining block leaves an editable empty paragraph
    expect(
      await deletePageBlock(singleEditor, singleEditor.document.root.children.single),
      isTrue,
    );
    expect(singleEditor.document.root.children.length, 1);
    expect(singleEditor.document.root.children.single.type, 'paragraph');
    expect(singleEditor.document.root.children.single.delta!.toPlainText(), isEmpty);

    singleEditor.dispose();
  });

  testWidgets('handle menu duplicates and deletes block', (t) async {
    await t.pumpWidget(app(reduced: true));
    await t.pumpAndSettle();

    await t.tap(handle(text));
    await t.pumpAndSettle();
    expect(find.text('Дублировать'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);

    await t.tap(find.text('Дублировать'));
    await t.pumpAndSettle();
    expect(editor.document.root.children.length, 4);
    expect(
      editor.document.root.children[2].delta!.toPlainText(),
      equals('Description above the query'),
    );

    await t.tap(handle(editor.document.root.children[2]));
    await t.pumpAndSettle();
    await t.tap(find.text('Удалить'));
    await t.pumpAndSettle();
    expect(order(), [code.id, text.id, last.id]);

    expect(t.takeException(), isNull);
    await finish(t);
  });

  test('turnPageBlockInto transforms block types and undoes cleanly', () async {
    final block = paragraphNode(text: 'Transformable paragraph');
    final singleEditor = EditorState(
      document: Document(root: pageNode(children: [block])),
    );

    // Paragraph -> Heading 1
    expect(
      await turnPageBlockInto(
        singleEditor,
        block,
        HeadingBlockKeys.type,
        attributes: {'level': 1},
      ),
      isTrue,
    );
    var current = singleEditor.document.root.children.first;
    expect(current.type, HeadingBlockKeys.type);
    expect(current.attributes['level'], 1);
    expect(current.delta!.toPlainText(), 'Transformable paragraph');

    // Heading 1 -> Bulleted list
    expect(
      await turnPageBlockInto(
        singleEditor,
        current,
        BulletedListBlockKeys.type,
      ),
      isTrue,
    );
    current = singleEditor.document.root.children.first;
    expect(current.type, BulletedListBlockKeys.type);
    expect(current.delta!.toPlainText(), 'Transformable paragraph');

    // Bulleted list -> Todo list
    expect(
      await turnPageBlockInto(
        singleEditor,
        current,
        TodoListBlockKeys.type,
      ),
      isTrue,
    );
    current = singleEditor.document.root.children.first;
    expect(current.type, TodoListBlockKeys.type);
    expect(current.delta!.toPlainText(), 'Transformable paragraph');

    // Todo list -> Code block
    expect(
      await turnPageBlockInto(
        singleEditor,
        current,
        codeBlockType,
        attributes: {'language': 'dart'},
      ),
      isTrue,
    );
    current = singleEditor.document.root.children.first;
    expect(current.type, codeBlockType);
    expect(current.delta!.toPlainText(), 'Transformable paragraph');

    // Undo returns back to Todo list
    singleEditor.undoManager.undo();
    current = singleEditor.document.root.children.first;
    expect(current.type, TodoListBlockKeys.type);

    singleEditor.dispose();
  });

  testWidgets('handle menu displays Turn into subpage and block options', (t) async {
    await t.pumpWidget(app(reduced: true));
    await t.pumpAndSettle();

    await t.tap(handle(text));
    await t.pumpAndSettle();

    // Verify block context menu rows
    expect(find.text('Превратить в…'), findsOneWidget);
    expect(find.text('Добавить блок выше'), findsOneWidget);
    expect(find.text('Добавить блок ниже'), findsOneWidget);
    expect(find.text('Дублировать'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);

    // Tap "Превратить в…"
    await t.tap(find.text('Превратить в…'));
    await t.pumpAndSettle();

    expect(find.text('Назад'), findsOneWidget);
    expect(find.text('Заголовок 1'), findsOneWidget);
    expect(find.text('Заголовок 2'), findsOneWidget);
    expect(find.text('Заголовок 3'), findsOneWidget);
    expect(find.text('Список с маркерами'), findsOneWidget);
    expect(find.text('Нумерованный список'), findsOneWidget);
    expect(find.text('Список задач'), findsOneWidget);
    expect(find.text('Цитата'), findsOneWidget);
    expect(find.text('Блок кода'), findsOneWidget);

    // Tap "Заголовок 1" to convert
    await t.tap(find.text('Заголовок 1'));
    await t.pumpAndSettle();

    expect(editor.document.root.children[1].type, HeadingBlockKeys.type);
    expect(editor.document.root.children[1].attributes['level'], 1);
    expect(
      editor.document.root.children[1].delta!.toPlainText(),
      'Description above the query',
    );

    expect(t.takeException(), isNull);
    await finish(t);
  });
}
