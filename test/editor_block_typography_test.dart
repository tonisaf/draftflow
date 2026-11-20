import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/l10n/locale_controller.dart';
import 'package:notes_here/ui/common/quiet_button.dart';
import 'package:notes_here/ui/editor/components/backlinks_section.dart';
import 'package:notes_here/ui/editor/components/notes_block_builders.dart';
import 'package:notes_here/ui/editor/components/notes_text_span_decorator.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Editor block typography & spacing', () {
    late AppDatabase db;
    late NotesRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildEditorHost({
      required EditorState editorState,
      bool smallText = false,
      Brightness brightness = Brightness.light,
    }) {
      final skin = Skin.of(brightness);
      return ChangeNotifierProvider(
        create: (_) => LocaleController(),
        child: MaterialApp(
          theme: ThemeData(brightness: brightness, extensions: [skin]),
          home: Scaffold(
            body: Builder(
              builder: (context) => AppFlowyEditor(
                editorState: editorState,
                blockComponentBuilders: buildNotesBlockComponentBuilders(
                  context,
                  smallText: smallText,
                  repository: repo,
                  initialDatabases: const {},
                ),
                editorStyle: EditorStyle.desktop(
                  textSpanDecorator: notesTextSpanDecorator,
                  textStyleConfiguration: TextStyleConfiguration(
                    text: TextStyle(
                      fontSize: smallText ? UiType.body : UiType.editorBody,
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

    testWidgets(
        'renders heading scale, asymmetric top/bottom padding, and keeps inline code color inside headings',
        (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            headingNode(level: 1, text: 'First heading'),
            paragraphNode(text: 'Body paragraph'),
            headingNode(
              level: 3,
              delta: Delta()
                ..insert('Section ')
                ..insert('codeSpan', attributes: {'code': true}),
            ),
          ],
        ),
      );
      final editorState = EditorState(document: doc);

      await tester.pumpWidget(buildEditorHost(editorState: editorState));
      await tester.pumpAndSettle();

      final builders = buildNotesBlockComponentBuilders(
        tester.element(find.byType(AppFlowyEditor)),
        smallText: false,
        repository: repo,
        initialDatabases: const {},
      );

      final dynamic headingBuilder = builders[HeadingBlockKeys.type];
      final firstHeadingPadding =
          headingBuilder.configuration.padding(doc.root.children[0]);
      final thirdHeadingPadding =
          headingBuilder.configuration.padding(doc.root.children[2]);

      expect(firstHeadingPadding.top, equals(UiSpace.s8));
      expect(thirdHeadingPadding.top, equals(UiSpace.s16));
      expect(
        thirdHeadingPadding.top,
        greaterThan(thirdHeadingPadding.bottom),
      );

      final h1Style = headingBuilder.textStyleBuilder!(1);
      final h3Style = headingBuilder.textStyleBuilder!(3);
      expect(h1Style.fontSize, equals(26.0));
      expect(h3Style.fontSize, equals(17.5));
      expect(h1Style.color, isNull);

      final skin = Skin.of(Brightness.light);
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final inlineCodeSpans = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text == 'codeSpan') {
            inlineCodeSpans.add(span);
          }
          span.children?.forEach(collect);
        }
      }

      for (final rt in richTexts) {
        collect(rt.text);
      }
      expect(inlineCodeSpans, isNotEmpty);
      expect(inlineCodeSpans.first.style?.color, equals(skin.inlineCode));
      expect(
        inlineCodeSpans.first.style?.backgroundColor,
        equals(Palette.transparent),
      );
    });

    testWidgets(
        'renders bullet markers, todo squircle checkboxes, quiet quote bar, and hairline divider',
        (tester) async {
      final doc = Document(
        root: pageNode(
          children: [
            bulletedListNode(
              text: 'Level 0 bullet',
              children: [
                bulletedListNode(
                  text: 'Level 1 bullet',
                  children: [bulletedListNode(text: 'Level 2 bullet')],
                ),
              ],
            ),
            todoListNode(checked: false, text: 'Open task'),
            todoListNode(checked: true, text: 'Done task'),
            quoteNode(delta: Delta()..insert('Calm quote')),
            dividerNode(),
          ],
        ),
      );
      final editorState = EditorState(document: doc);

      await tester.pumpWidget(buildEditorHost(editorState: editorState));
      await tester.pumpAndSettle();

      // Quote bar uses calm skin.outline rather than AppFlowy cyan (#00BCF0).
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasLegacyCyan = containers.any(
        (c) =>
            c.color == const Color(0xFF00BCF0) ||
            (c.decoration is BoxDecoration &&
                (c.decoration as BoxDecoration).color ==
                    const Color(0xFF00BCF0)),
      );
      expect(hasLegacyCyan, isFalse);

      // Todo checked state applies strike-through styling via TodoListBlockComponentBuilder.
      final skin = Skin.of(Brightness.light);
      final builders = buildNotesBlockComponentBuilders(
        tester.element(find.byType(AppFlowyEditor)),
        smallText: false,
        repository: repo,
        initialDatabases: const {},
      );
      final todoBuilder =
          builders[TodoListBlockKeys.type] as TodoListBlockComponentBuilder;
      final doneStyle = todoBuilder.textStyleBuilder!(true);
      expect(doneStyle.decoration, equals(TextDecoration.lineThrough));
      expect(doneStyle.color, equals(skin.muted));

      final dividerBuilder =
          builders[DividerBlockKeys.type] as DividerBlockComponentBuilder;
      expect(dividerBuilder.lineColor, equals(skin.hairlineBorder));
    });
  });

  group('BacklinksSection redesign', () {
    testWidgets('uses QuietButton, toggles expansion, and navigates on tap',
        (tester) async {
      String? navigatedId;
      final now = DateTime(2026, 11, 11);
      final pages = [
        Page(
          id: 'p1',
          title: 'Architecture Spec',
          parentId: null,
          icon: '📐',
          cover: null,
          orderKey: 'a0',
          databaseId: null,
          properties: '{}',
          titleFolded: null,
          propertiesFolded: null,
          createdAt: now,
          trashedAt: null,
          trashBatchId: null,
        ),
        Page(
          id: 'p2',
          title: '   ',
          parentId: null,
          icon: null,
          cover: null,
          orderKey: 'a1',
          databaseId: null,
          properties: '{}',
          titleFolded: null,
          propertiesFolded: null,
          createdAt: now,
          trashedAt: null,
          trashBatchId: null,
        ),
      ];

      final skin = Skin.of(Brightness.light);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleController(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ru'),
            theme: ThemeData(brightness: Brightness.light, extensions: [skin]),
            home: Scaffold(
              body: BacklinksSection(
                backlinks: pages,
                onNavigateToPage: (id) => navigatedId = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuietButton), findsNWidgets(3));
      expect(find.text('Architecture Spec'), findsOneWidget);

      await tester.tap(find.text('Architecture Spec'));
      await tester.pumpAndSettle();
      expect(navigatedId, equals('p1'));

      // Collapse and re-expand header
      await tester.tap(find.byType(QuietButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Architecture Spec'), findsNothing);

      await tester.tap(find.byType(QuietButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Architecture Spec'), findsOneWidget);
    });
  });

  group('Title Enter navigation into editor body', () {
    testWidgets(
        'submitting page title focuses editor at first block and saves title',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      late String pageId;
      await tester.runAsync(() async {
        pageId = await repo.createPage(title: 'Initial');
        await repo.savePageNodes(pageId, [paragraphNode(text: 'First line')]);
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
                title: 'Initial',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleFinder = find.byKey(const Key('page_title_input'));
      expect(titleFinder, findsOneWidget);
      await tester.tap(titleFinder);
      await tester.pump();
      await tester.enterText(titleFinder, 'Updated Heading');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final editorWidget =
          tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      expect(editorWidget.focusNode?.hasFocus, isTrue);
      expect(
        editorWidget.editorState.selection,
        equals(Selection.collapsed(Position(path: [0]))),
      );

      await tester.runAsync(() async {
        final saved = await repo.getPage(pageId);
        expect(saved?.title, equals('Updated Heading'));
      });

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });

    testWidgets(
        'submitting title on divider-first page prepends an empty editable paragraph',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      late String pageId;
      await tester.runAsync(() async {
        pageId = await repo.createPage(title: 'Divider Start');
        await repo.savePageNodes(pageId, [dividerNode()]);
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
                title: 'Divider Start',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('page_title_input')));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final editorWidget =
          tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      expect(editorWidget.focusNode?.hasFocus, isTrue);
      expect(editorWidget.editorState.document.root.children.length, equals(2));
      expect(
        editorWidget.editorState.document.root.children[0].type,
        equals(ParagraphBlockKeys.type),
      );
      expect(
        editorWidget.editorState.document.root.children[1].type,
        equals(DividerBlockKeys.type),
      );
      expect(
        editorWidget.editorState.selection,
        equals(Selection.collapsed(Position(path: [0]))),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
    });
  });
}
