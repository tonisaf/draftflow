import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/services/export_import_service.dart';
import 'package:notes_here/ui/editor/components/callout_block_component.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/editor/components/html_paste.dart';
import 'package:notes_here/ui/editor/components/notes_block_builders.dart';
import 'package:notes_here/ui/editor/components/notes_text_span_decorator.dart';
import 'package:notes_here/ui/editor/components/page_block_reorder.dart';
import 'package:notes_here/ui/editor/components/toggle_block_component.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Callout & Toggle blocks', () {
    late AppDatabase db;
    late NotesRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildHost(
      EditorState editorState, {
      Brightness brightness = Brightness.light,
    }) {
      final skin = Skin.of(brightness);
      return ChangeNotifierProvider(
        create: (_) => LocaleController(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          theme: buildTheme(brightness),
          home: Scaffold(
            body: Builder(
              builder: (context) => AppFlowyEditor(
                editorState: editorState,
                blockComponentBuilders: buildNotesBlockComponentBuilders(
                  context,
                  smallText: false,
                  repository: repo,
                  initialDatabases: const {},
                ),
                characterShortcutEvents: buildEditorCharacterShortcuts(
                  selectionMenuItems: buildEditorSelectionMenuItems(
                    skin: skin,
                    repository: repo,
                    pageId: 'test-page',
                    onInsertPageMention: (_, {isWikilink = false}) async {},
                  ),
                  selectionMenuStyle: getSelectionMenuStyle(
                    skin,
                    brightness == Brightness.dark,
                  ),
                  onInsertPageMention: (_, {isWikilink = false}) async {},
                ),
                editorStyle: EditorStyle.desktop(
                  textSpanDecorator: notesTextSpanDecorator,
                  textStyleConfiguration: TextStyleConfiguration(
                    text: TextStyle(
                      fontSize: UiType.editorBody,
                      height: UiType.editorLineHeight,
                      color: skin.text,
                    ),
                    code: TextStyle(
                      fontFamily: 'Consolas',
                      color: skin.inlineCode,
                      backgroundColor: skin.inlineCodeSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Callout renders icon, text, and updates icon via picker',
        (tester) async {
      final callout = calloutNode(
        icon: '💡',
        delta: Delta()
          ..insert('Важно: ')
          ..insert('task-493', attributes: {'code': true}),
      );
      final doc = Document(root: pageNode(children: [callout]));
      final editorState = EditorState(document: doc);

      await tester.pumpWidget(buildHost(editorState));
      await tester.pumpAndSettle();

      expect(find.byType(CalloutBlockComponentWidget), findsOneWidget);
      expect(find.text('💡'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('callout_icon_${callout.id}')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚀').first);
      await tester.pumpAndSettle();

      expect(
        editorState.document.root.children.first.attributes[CalloutBlockKeys.icon],
        equals('🚀'),
      );
    });

    testWidgets(
        'Toggle collapses/expands children and adds first child from empty hint',
        (tester) async {
      final emptyToggle = toggleNode(text: 'Пустой раздел');
      final populatedToggle = toggleNode(
        text: 'Детали',
        children: [paragraphNode(text: 'Скрытый текст')],
      );
      final doc = Document(
        root: pageNode(children: [emptyToggle, populatedToggle]),
      );
      final editorState = EditorState(document: doc);

      await tester.pumpWidget(buildHost(editorState));
      await tester.pumpAndSettle();

      expect(find.byType(ToggleBlockComponentWidget), findsNWidgets(2));
      expect(find.byKey(ValueKey('toggle_empty_add_${emptyToggle.id}')), findsOneWidget);

      // Tap empty toggle hint to add child paragraph
      await tester.tap(find.byKey(ValueKey('toggle_empty_add_${emptyToggle.id}')));
      await tester.pumpAndSettle();
      expect(emptyToggle.children.length, equals(1));
      expect(emptyToggle.children.single.type, equals(ParagraphBlockKeys.type));

      // Collapse populated toggle
      await tester.tap(find.byKey(ValueKey('toggle_chevron_${populatedToggle.id}')));
      await tester.pumpAndSettle();
      expect(populatedToggle.attributes[ToggleBlockKeys.collapsed], isTrue);

      // Re-expand populated toggle
      await tester.tap(find.byKey(ValueKey('toggle_chevron_${populatedToggle.id}')));
      await tester.pumpAndSettle();
      expect(populatedToggle.attributes[ToggleBlockKeys.collapsed], isFalse);
    });

    test('Enter behavior in Callout and Toggle + `> ` shortcut', () async {
      final p = paragraphNode(text: '>');
      final callout = calloutNode(text: 'Callout body');
      final expandedToggle = toggleNode(collapsed: false, text: 'Open');
      final collapsedToggle = toggleNode(
        collapsed: true,
        text: 'Closed',
        children: [paragraphNode(text: 'Hidden')],
      );
      final emptyCallout = calloutNode(text: '');

      final editorState = EditorState(
        document: Document(
          root: pageNode(
            children: [p, callout, expandedToggle, collapsedToggle, emptyCallout],
          ),
        ),
      );

      final shortcuts = buildEditorCharacterShortcuts(
        selectionMenuItems: const [],
        selectionMenuStyle: getSelectionMenuStyle(Skin.of(Brightness.light), false),
        onInsertPageMention: (_, {isWikilink = false}) async {},
      );

      // `> ` converts paragraph into Toggle
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [0], offset: 1)),
      );
      final gtHandler = shortcuts.firstWhere(
        (e) => e.key == 'format greater to toggle list',
      );
      expect(await gtHandler.handler(editorState), isTrue);
      expect(editorState.document.root.children[0].type, equals(toggleBlockType));

      // Enter inside non-empty Callout inserts paragraph below
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [1], offset: 12)),
      );
      final calloutEnter = shortcuts.firstWhere(
        (e) => e.key == 'insert newline in callout block',
      );
      expect(await calloutEnter.handler(editorState), isTrue);
      expect(editorState.document.root.children[2].type, equals(ParagraphBlockKeys.type));

      // Enter inside expanded Toggle creates first child [3, 0]
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [3], offset: 4)),
      );
      final toggleEnter = shortcuts.firstWhere(
        (e) => e.key == 'insert newline in toggle block',
      );
      expect(await toggleEnter.handler(editorState), isTrue);
      expect(editorState.document.root.children[3].children.length, equals(1));
      expect(editorState.selection, equals(Selection.collapsed(Position(path: [3, 0]))));

      // Enter inside collapsed Toggle inserts sibling after toggle
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [4], offset: 6)),
      );
      expect(await toggleEnter.handler(editorState), isTrue);
      expect(editorState.document.root.children[5].type, equals(ParagraphBlockKeys.type));

      // Enter inside empty Callout converts it back to paragraph
      editorState.updateSelectionWithReason(
        Selection.collapsed(Position(path: [6], offset: 0)),
      );
      expect(await calloutEnter.handler(editorState), isTrue);
      expect(editorState.document.root.children[6].type, equals(ParagraphBlockKeys.type));
    });

    test('Slash menu, HTML paste/encode, duplication, and Markdown export support Callout & Toggle',
        () async {
      final items = buildEditorSelectionMenuItems(
        skin: Skin.of(Brightness.light),
        repository: repo,
        pageId: 'p1',
        onInsertPageMention: (_, {isWikilink = false}) async {},
      );
      expect(
        items.any((i) => i.keywords.contains('callout')),
        isTrue,
      );
      expect(
        items.any((i) => i.keywords.contains('toggle')),
        isTrue,
      );

      // HTML paste -> nodes -> HTML encode roundtrip
      const rawHtml = '''
<aside data-callout-icon="⚡"><p>Fast note</p></aside>
<details open>
  <summary>Summary title</summary>
  <p>Nested detail</p>
</details>
''';
      final nodes = htmlToEditorNodes(rawHtml);
      expect(nodes.length, equals(2));
      expect(nodes[0].type, equals(calloutBlockType));
      expect(nodes[0].attributes[CalloutBlockKeys.icon], equals('⚡'));
      expect(nodes[1].type, equals(toggleBlockType));
      expect(nodes[1].attributes[ToggleBlockKeys.collapsed], isFalse);
      expect(nodes[1].delta!.toPlainText(), equals('Summary title'));
      expect(nodes[1].children.single.delta!.toPlainText(), equals('Nested detail'));

      final encoded = documentToHTML(
        Document(root: pageNode(children: nodes)),
        customParsers: const [HTMLCalloutNodeParser(), HTMLToggleNodeParser()],
      );
      expect(encoded, contains('<aside data-callout-icon="⚡">'));
      expect(encoded, contains('<details open="">'));
      expect(encoded, contains('<summary>Summary title</summary>'));

      // Duplicate Toggle keeps children with fresh IDs
      final editorState = EditorState(
        document: Document(root: pageNode(children: [nodes[1]])),
      );
      final clone = await duplicatePageBlock(editorState, nodes[1]);
      expect(clone, isNotNull);
      expect(clone!.children.single.id, isNot(equals(nodes[1].children.single.id)));

      // ExportImportService Markdown export
      final pageId = await repo.createPage(title: 'Blocks Export');
      await repo.savePageNodes(pageId, [nodes[0], nodes[1]]);
      final service = ExportImportService(repository: repo);
      final md = await service.exportPageToMarkdown(pageId);
      expect(md, contains('> ⚡ Fast note'));
      expect(md, contains('<details>'));
      expect(md, contains('<summary>Summary title</summary>'));
      expect(md, contains('Nested detail'));
    });
  });
}
