import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/common/page_link_utils.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/editor/components/page_more_actions_button.dart';
import 'package:notes_here/ui/home_screen.dart';
import 'package:notes_here/ui/sidebar/sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Page Link Formatting', () {
    test('formatPageLinkDetails handles titled page with icon', () {
      final link = formatPageLinkDetails(
        id: '123-abc',
        title: 'Project Roadmap',
        icon: '🚀',
      );
      expect(link, equals('[🚀 Project Roadmap](page://123-abc)'));
    });

    test('formatPageLinkDetails handles untitled page with icon', () {
      final link = formatPageLinkDetails(
        id: '123-abc',
        title: '   ',
        icon: '📝',
      );
      expect(link, equals('[📝 Untitled](page://123-abc)'));
    });

    test('formatPageLinkDetails handles page without icon', () {
      final link = formatPageLinkDetails(
        id: '456-def',
        title: 'Meeting Notes',
        icon: null,
      );
      expect(link, equals('[Meeting Notes](page://456-def)'));
    });
  });

  group('Page Link Clipboard & UI Feedback', () {
    late AppDatabase db;
    late NotesRepository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = NotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('copyPageLinkDetailsToClipboard sets clipboard and displays floating snackbar',
        (tester) async {
      String? pastedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            pastedText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  copyPageLinkDetailsToClipboard(
                    context,
                    pageId: 'page-999',
                    title: 'Specifications',
                    icon: '📘',
                  );
                },
                child: const Text('Copy'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(pastedText, equals('[📘 Specifications](page://page-999)'));
      expect(find.text('Link to "Specifications" copied to clipboard'), findsOneWidget);
    });

    testWidgets('PageMoreActionsButton contains Copy link to page option', (tester) async {
      bool copyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PageMoreActionsButton(
                onCopyPageLink: () => copyCalled = true,
                onExportMarkdown: () {},
                onImportNotionCsv: () {},
                onImportMarkdown: () {},
                onCopyMarkdown: () {},
                onSaveMarkdownToFile: () {},
                onOpenBackup: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PageMoreActionsButton));
      await tester.pumpAndSettle();

      expect(find.text('Copy link to page'), findsOneWidget);
      expect(find.text('Ctrl+Alt+L'), findsOneWidget);

      await tester.tap(find.text('Copy link to page'));
      await tester.pumpAndSettle();

      expect(copyCalled, isTrue);
    });

    testWidgets('Sidebar page context menu contains Copy link to page option', (tester) async {
      final pageId = await repo.createPage(title: 'Sidebar Page', icon: '📁');
      final page = (await repo.getPage(pageId))!;

      String? pastedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            pastedText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Sidebar(
              pages: [page],
              selectedPageId: pageId,
              onSelectPage: (_) {},
              onNewRootPage: () {},
              onNewSubpage: (_) {},
              onTrashPage: (_) {},
              onOpenSearch: () {},
              onExportPage: (_) {},
              onImportNotionCsv: (_) {},
              onToggleTrash: () {},
              onMovePage: (_, {nextOrderKey, prevOrderKey, targetParentId}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right-click on the page title
      await tester.tap(find.text('Sidebar Page'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Copy link to page'), findsOneWidget);
      await tester.tap(find.text('Copy link to page'));
      await tester.pumpAndSettle();

      expect(pastedText, equals('[📁 Sidebar Page](page://$pageId)'));
      expect(find.text('Link to "Sidebar Page" copied to clipboard'), findsOneWidget);
    });

    testWidgets('HomeScreen ⌥⌘L shortcut triggers Copy link to page', (tester) async {
      final pageId = await repo.createPage(title: 'Global Shortcut Test', icon: '⚡');

      String? pastedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            pastedText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger ⌥⌘L chord
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(pastedText, equals('[⚡ Global Shortcut Test](page://$pageId)'));
      expect(find.text('Link to "Global Shortcut Test" copied to clipboard'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();
    });

    test('smartLinkPasteCommand inserts rich link when pasting internal page link',
        () async {
      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(
              delta: Delta()..insert('See reference: '),
            ),
          ],
        ),
      );
      final editorState = EditorState(document: doc);
      // Position cursor at end of paragraph (offset 15)
      editorState.updateSelectionWithReason(
        Selection.collapsed(
          Position(path: [0], offset: 15),
        ),
      );

      // Mock AppFlowyClipboard with an internal page link markdown
      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(
          text: '[🚀 Launch Checklist](page://checklist-page-uuid)',
        ),
      );

      // Invoke smartLinkPasteCommand handler
      final result = smartLinkPasteCommand.handler(editorState);
      expect(result, equals(KeyEventResult.handled));

      // Wait microtasks for async clipboard paste to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final node = editorState.getNodeAtPath([0]);
      expect(node, isNotNull);
      final delta = node!.delta!;
      final plainText = delta.toPlainText();
      expect(plainText, equals('See reference: 🚀 Launch Checklist'));

      // Verify that "🚀 Launch Checklist" has href attribute
      final operations = delta.toList();
      final linkOp = operations.firstWhere(
        (op) => op.attributes?[AppFlowyRichTextKeys.href] == 'page://checklist-page-uuid',
      );
      expect(linkOp.data, equals('🚀 Launch Checklist'));

      AppFlowyClipboard.mockSetData(null);
    });

    test('smartLinkPasteCommand formats selected text when pasting bare page:// link',
        () async {
      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(
              delta: Delta()..insert('Click here for details'),
            ),
          ],
        ),
      );
      final editorState = EditorState(document: doc);
      // Select "here" (offset 6 to 10)
      editorState.updateSelectionWithReason(
        Selection(
          start: Position(path: [0], offset: 6),
          end: Position(path: [0], offset: 10),
        ),
      );

      AppFlowyClipboard.mockSetData(
        const AppFlowyClipboardData(
          text: 'page://target-page-uuid',
        ),
      );

      final result = smartLinkPasteCommand.handler(editorState);
      expect(result, equals(KeyEventResult.handled));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final node = editorState.getNodeAtPath([0]);
      final delta = node!.delta!;
      final linkOp = delta.toList().firstWhere(
        (op) => op.attributes?[AppFlowyRichTextKeys.href] == 'page://target-page-uuid',
      );
      expect(linkOp.data, equals('here'));

      AppFlowyClipboard.mockSetData(null);
    });
  });
}
