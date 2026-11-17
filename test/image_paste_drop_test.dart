import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/platform/desktop_services.dart';
import 'package:notes_here/services/export_import_service.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/editor/components/html_paste.dart';
import 'package:notes_here/ui/editor/components/image_paste.dart';
import 'package:notes_here/ui/editor/components/notes_image_component.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:provider/provider.dart';

// 1x1 transparent PNG bytes.
final Uint8List _samplePng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const macosWindowChannel = MethodChannel('notes_here/macos_window');

  tearDown(() {
    AppFlowyClipboard.mockSetData(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(macosWindowChannel, null);
    DesktopImageDropBridge.isHovering.value = false;
  });

  group('Image helpers & MIME detection', () {
    test('extracts base64 from data URIs and sniffs image mime types', () {
      final raw = base64Encode(_samplePng);
      expect(
        stripDataImageUriBase64('data:image/png;base64,$raw'),
        equals(raw),
      );
      expect(stripDataImageUriBase64('https://example.com/a.png'), isNull);
      expect(inferImageMimeType(_samplePng), equals('image/png'));
      expect(
        inferImageMimeType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        equals('image/jpeg'),
      );
      expect(inferImageMimeTypeFromBase64(raw), equals('image/png'));
    });

    test('parses data URI img HTML and encodes back via HTMLImageDataUriParser',
        () {
      final raw = base64Encode(_samplePng);
      final html = '<img src="data:image/png;base64,$raw">';
      expect(hasRichSemanticHtml(html), isTrue);
      expect(hasRichTextAlongsideImages(html), isFalse);

      final nodes = htmlToEditorNodes(html);
      expect(nodes.length, equals(1));
      expect(nodes.first.type, equals(ImageBlockKeys.type));
      expect(nodes.first.attributes[ImageBlockKeys.url], equals(raw));

      final encoded = documentToHTML(
        Document(root: pageNode(children: nodes)),
        customParsers: const [HTMLImageDataUriParser()],
      );
      expect(encoded, contains('data:image/png;base64,$raw'));
    });
  });

  group('Clipboard image paste & Markdown export', () {
    test('smartLinkPasteCommand pastes compressed PNG from macOS pasteboard',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(macosWindowChannel, (call) async {
        if (call.method == 'getClipboardImages') {
          return <Uint8List>[_samplePng];
        }
        return null;
      });

      final doc = Document.blank(withInitialText: true);
      final editorState = EditorState(document: doc);
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 0)),
      );

      // Finder often includes filename in plain text alongside image data.
      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(text: 'screenshot.png'),
      );

      final result = smartLinkPasteCommand.handler(editorState);
      expect(result, equals(KeyEventResult.handled));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final children = editorState.document.root.children.toList();
      expect(children.length, equals(1));
      expect(children.first.type, equals(ImageBlockKeys.type));
      expect(
        children.first.attributes[ImageBlockKeys.url],
        equals(base64Encode(_samplePng)),
      );
    });

    test('ExportImportService exports base64 imageNode as data URI markdown',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final pageId = await repo.createPage(title: 'Image Export');
      final raw = base64Encode(_samplePng);
      await repo.savePageNodes(pageId, [imageNode(url: raw)]);

      final md = await ExportImportService(repository: repo)
          .exportPageToMarkdown(pageId);
      expect(md, contains('![image](data:image/png;base64,$raw)'));

      await db.close();
    });
  });

  group('Native Drag & Drop overlay and insertion in PageEditorView', () {
    testWidgets('shows drop overlay on drag hover and inserts image on drop',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      late String pageId;
      await tester.runAsync(() async {
        pageId = await repo.createPage(title: 'Drop Target');
      });

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleController(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: PageEditorView(
                repository: repo,
                pageId: pageId,
                title: 'Drop Target',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const codec = StandardMethodCodec();
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;

      // Simulate native NSWindow draggingEntered
      await messenger.handlePlatformMessage(
        'notes_here/macos_window',
        codec.encodeMethodCall(
          const MethodCall('onImageDragState', {'hovering': true}),
        ),
        (_) {},
      );
      await tester.pump();
      expect(find.byKey(const Key('page_image_drop_overlay')), findsOneWidget);

      // Simulate native NSWindow performDragOperation
      await messenger.handlePlatformMessage(
        'notes_here/macos_window',
        codec.encodeMethodCall(
          MethodCall('onImagesDropped', {
            'images': [_samplePng],
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page_image_drop_overlay')), findsNothing);
      final editorWidget =
          tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final children = editorWidget.editorState.document.root.children.toList();
      expect(children.length, equals(1));
      expect(children.first.type, equals(ImageBlockKeys.type));
      expect(
        children.first.attributes[ImageBlockKeys.url],
        equals(base64Encode(_samplePng)),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });

    testWidgets('image hover toolbar aligns, copies, and deletes image block',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final raw = base64Encode(_samplePng);
      late String pageId;
      await tester.runAsync(() async {
        pageId = await repo.createPage(title: 'Image Toolbar');
        await repo.savePageNodes(pageId, [imageNode(url: raw)]);
      });

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleController(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: PageEditorView(
                repository: repo,
                pageId: pageId,
                title: 'Image Toolbar',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editorWidget =
          tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final imgNode = editorWidget.editorState.document.root.children.single;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(find.byType(NotesImageBlockComponentWidget)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('image_toolbar_${imgNode.id}')), findsOneWidget);

      await tester.tap(find.byTooltip('Left'));
      await tester.pumpAndSettle();
      expect(
        editorWidget.editorState.document.root.children.single
            .attributes[ImageBlockKeys.align],
        equals('left'),
      );

      await tester.tap(find.byTooltip('Удалить'));
      await tester.pumpAndSettle();
      expect(
        editorWidget.editorState.document.root.children.single.type,
        equals(ParagraphBlockKeys.type),
      );

      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });

    testWidgets('renders JPEG base64 starting with /9j/ via MemoryImage',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final jpegBytes = Uint8List.fromList(<int>[
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0xFF, 0xD9,
      ]);
      final jpegBase64 = base64Encode(jpegBytes);
      expect(jpegBase64.startsWith('/9j/'), isTrue);

      late String pageId;
      await tester.runAsync(() async {
        pageId = await repo.createPage(title: 'JPEG Base64');
        await repo.savePageNodes(pageId, [imageNode(url: jpegBase64)]);
      });

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleController(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: PageEditorView(
                repository: repo,
                pageId: pageId,
                title: 'JPEG Base64',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final imageFinder = find.descendant(
        of: find.byType(NotesImageBlockComponentWidget),
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      expect(tester.widget<Image>(imageFinder).image, isA<MemoryImage>());

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });

    testWidgets(
        'image selection highlights image frame cleanly and blocks can be inserted above and below',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final raw = base64Encode(_samplePng);
      late String pageId;
      await tester.runAsync(() async {
        pageId = await repo.createPage(title: 'Image Flow');
        await repo.savePageNodes(pageId, [
          imageNode(url: raw, width: 180, height: 80),
        ]);
      });

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleController(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: PageEditorView(
                repository: repo,
                pageId: pageId,
                title: 'Image Flow',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editorWidget =
          tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final editorState = editorWidget.editorState;
      final imgFinder = find.byType(NotesImageBlockComponentWidget);
      final imgNode = editorState.document.root.children.single;

      // 1. Selecting the image keeps selection rects non-negative inside the
      // centered frame rather than drawing a sharp half-width box on the left.
      await tester.tap(find.descendant(of: imgFinder, matching: find.byType(Image)));
      await tester.pumpAndSettle();
      expect(editorState.selection?.start.path, equals([0]));

      final selectable = imgNode.selectable!;
      final cursorRect = selectable.getCursorRectInPosition(
        Position(path: [0], offset: 0),
      )!;
      expect(cursorRect.left, greaterThanOrEqualTo(0));
      expect(cursorRect.width, closeTo(180, 2));
      expect(
        selectable.getRectsInSelection(editorState.selection!).single,
        equals(cursorRect),
      );

      // 2. Pressing Enter while image is selected inserts a paragraph below
      // without deleting the image.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      var children = editorState.document.root.children.toList();
      expect(children.map((n) => n.type), equals(['image', 'paragraph']));
      expect(editorState.selection?.start.path, equals([1]));

      // 3. Re-selecting image and pressing Shift+Enter inserts a paragraph above.
      await tester.tap(find.descendant(of: imgFinder, matching: find.byType(Image)));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      children = editorState.document.root.children.toList();
      expect(
        children.map((n) => n.type),
        equals(['paragraph', 'image', 'paragraph']),
      );
      expect(editorState.selection?.start.path, equals([0]));

      // 4. Clicking trailing area below the last block appends a paragraph when
      // the last block is an image.
      await tester.runAsync(() async {
        final tx = editorState.transaction
          ..deleteNodes([children.last]);
        await editorState.apply(tx);
      });
      await tester.pumpAndSettle();
      expect(
        editorState.document.root.children.map((n) => n.type),
        equals(['paragraph', 'image']),
      );

      await tester.tap(find.byKey(const Key('page_trailing_tap_area')));
      await tester.pumpAndSettle();
      children = editorState.document.root.children.toList();
      expect(
        children.map((n) => n.type),
        equals(['paragraph', 'image', 'paragraph']),
      );
      expect(editorState.selection?.start.path, equals([2]));

      // 5. Block handle (::) menu offers inserting above and below directly.
      final image = editorState.document.root.children[1];
      await tester.tap(
        find.byKey(ValueKey('page_block_handle_${image.id}')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить блок выше'));
      await tester.pumpAndSettle();
      expect(
        editorState.document.root.children.map((n) => n.type),
        equals(['paragraph', 'paragraph', 'image', 'paragraph']),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });
  });
}
