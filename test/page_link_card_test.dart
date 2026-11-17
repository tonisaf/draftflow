import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/app_icons.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/editor/components/page_link_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(db);
  });

  tearDown(() async {
    AppFlowyClipboard.mockSetData(null);
    await db.close();
  });

  group('PageLinkNode & PageLinkBlockComponent', () {
    test('creates pageLinkNode with attributes', () {
      final node = pageLinkNode(
        pageId: 'page-123',
        title: 'Project Roadmap',
        icon: '🚀',
      );

      expect(node.type, equals(pageLinkBlockType));
      expect(node.attributes[PageLinkBlockKeys.pageId], equals('page-123'));
      expect(node.attributes[PageLinkBlockKeys.title], equals('Project Roadmap'));
      expect(node.attributes[PageLinkBlockKeys.icon], equals('🚀'));
    });

    testWidgets('renders PageLinkBlockComponentWidget and handles tap navigation', (
      tester,
    ) async {
      final pageId = await repository.createPage(
        title: 'Architecture Guide',
        icon: '📐',
      );

      String? navigatedPageId;

      final doc = Document(
        root: pageNode(
          children: [
            pageLinkNode(
              pageId: pageId,
              title: 'Architecture Guide',
              icon: '📐',
            ),
          ],
        ),
      );

      final editorState = EditorState(document: doc);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editorState,
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                pageLinkBlockType: PageLinkBlockComponentBuilder(
                  repository: repository,
                  onNavigateToPage: (id) => navigatedPageId = id,
                ),
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Architecture Guide'), findsOneWidget);
      expect(find.text('📐'), findsOneWidget);
      expect(find.byIcon(AppIcons.arrowUpRightSquare), findsOneWidget);

      await tester.tap(find.text('Architecture Guide'));
      await tester.pumpAndSettle();

      expect(navigatedPageId, equals(pageId));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('pasting markdown page link on empty paragraph replaces it with pageLinkNode', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('notes_here/macos_window'),
        (call) async => null,
      );

      final pageId = await repository.createPage(title: 'Roadmap');

      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(),
          ],
        ),
      );

      final editorState = EditorState(document: doc);
      editorState.selection = Selection.collapsed(Position(path: [0], offset: 0));

      AppFlowyClipboard.mockSetData(
        AppFlowyClipboardData(text: '[🚀 Roadmap](page://$pageId)'),
      );

      smartLinkPasteCommand.handler(editorState);
      await tester.pumpAndSettle();

      expect(doc.root.children.first.type, equals(pageLinkBlockType));
      expect(
        doc.root.children.first.attributes[PageLinkBlockKeys.pageId],
        equals(pageId),
      );
    });

    testWidgets('selection menu card item replaces command paragraph with pageLinkNode', (
      tester,
    ) async {
      final targetPageId = await repository.createPage(
        title: 'Specifications',
        icon: '📑',
      );

      final doc = Document(
        root: pageNode(
          children: [
            paragraphNode(text: '/card'),
          ],
        ),
      );

      final editorState = EditorState(document: doc);
      editorState.selection =
          Selection.collapsed(Position(path: [0], offset: 5));

      final items = buildEditorSelectionMenuItems(
        skin: Skin.of(Brightness.light),
        repository: repository,
        pageId: 'current-page',
        onInsertPageMention: (_, {isWikilink = false}) async {},
      );

      final cardItem = items.firstWhere((it) => it.keywords.contains('card'));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    cardItem.handler(
                      editorState,
                      _MockMenuService(),
                      ctx,
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Specifications'), findsOneWidget);
      await tester.tap(find.text('Specifications'));
      await tester.pumpAndSettle();

      expect(doc.root.children.first.type, equals(pageLinkBlockType));
      expect(
        doc.root.children.first.attributes[PageLinkBlockKeys.pageId],
        equals(targetPageId),
      );
    });
  });
}

class _MockMenuService implements SelectionMenuService {
  @override
  Alignment get alignment => Alignment.topLeft;

  @override
  void dismiss() {}

  @override
  (double?, double?, double?, double?) getPosition() => (0, 0, null, null);

  @override
  Offset get offset => Offset.zero;

  @override
  Future<void> show() async {}

  @override
  SelectionMenuStyle get style => const SelectionMenuStyle(
        selectionMenuBackgroundColor: Colors.white,
        selectionMenuItemTextColor: Colors.black,
        selectionMenuItemIconColor: Colors.black,
        selectionMenuItemSelectedTextColor: Colors.blue,
        selectionMenuItemSelectedIconColor: Colors.blue,
        selectionMenuItemSelectedColor: Colors.grey,
        selectionMenuUnselectedLabelColor: Colors.grey,
        selectionMenuDividerColor: Colors.grey,
        selectionMenuLinkBorderColor: Colors.grey,
        selectionMenuInvalidLinkColor: Colors.red,
        selectionMenuButtonColor: Colors.grey,
        selectionMenuButtonTextColor: Colors.black,
        selectionMenuButtonIconColor: Colors.black,
        selectionMenuButtonBorderColor: Colors.grey,
        selectionMenuTabIndicatorColor: Colors.blue,
      );
}
