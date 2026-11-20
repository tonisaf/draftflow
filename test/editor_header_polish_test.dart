import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/ui/editor/components/editor_flowy_config.dart';
import 'package:notes_here/ui/editor/components/page_breadcrumbs.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

class _MenuService extends Fake implements SelectionMenuService {}

class _Repository extends NotesRepository {
  _Repository(super.db);
  final created = Completer<String>();
  @override
  Future<String> createDatabase({
    String title = 'Untitled Database',
    String? icon,
    String? parentPageId,
    List<({String name, String type, String? options, double width})>?
    initialColumns,
  }) async {
    final id = await super.createDatabase(
      title: title,
      icon: icon,
      parentPageId: parentPageId,
      initialColumns: initialColumns,
    );
    created.complete(id);
    return id;
  }
}

void main() {
  testWidgets(
    'breadcrumb hover stays neutral without underlining and remains navigable',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: BreadcrumbItem(
              title: 'Getting Started ⚡',
              icon: '💡',
              isCurrent: false,
              onTap: () => opened = true,
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('Getting Started ⚡')));
      await tester.pump();
      final label = tester.widget<Text>(find.text('Getting Started ⚡'));
      expect(label.style!.decoration, TextDecoration.none);
      expect(label.style!.color, Skin.of(Brightness.light).hint);
      await tester.tap(find.text('Getting Started ⚡'));
      expect(opened, true);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'choosing a database consumes the slash command instead of leaving a paragraph',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = _Repository(db);
      final state = EditorState(
        document: Document(
          root: pageNode(
            children: [paragraphNode(delta: Delta()..insert('/table'))],
          ),
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                context = ctx;
                return AppFlowyEditor(
                  editorState: state,
                  blockComponentBuilders: {
                    ...standardBlockComponentBuilderMap,
                    databaseBlockType: DatabaseBlockComponentBuilder(
                      repository: repo,
                    ),
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      state.selection = Selection.collapsed(Position(path: [0], offset: 6));
      final items = buildEditorSelectionMenuItems(
        skin: Skin.of(Brightness.light),
        repository: repo,
        pageId: 'parent',
        onInsertPageMention: (_, {bool isWikilink = false}) async {},
      );
      items
          .firstWhere((item) => item.name == 'Table view / Database')
          .handler(state, _MenuService(), context);
      await tester.runAsync(() => repo.created.future);
      await tester.pumpAndSettle();
      expect(state.document.root.children.length, 1);
      expect(state.document.root.children.single.type, databaseBlockType);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );

  testWidgets(
    'opening a legacy document clears only a slash directly before a database',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final page = await repo.createPage(title: 'Legacy');
      final database = await repo.createDatabase(parentPageId: page);
      await repo.savePageNodes(page, [
        paragraphNode(delta: Delta()..insert('/')),
        databaseBlockNode(databaseId: database),
        paragraphNode(delta: Delta()..insert('Keep / path')),
        paragraphNode(delta: Delta()..insert('/')),
        paragraphNode(delta: Delta()..insert('Ordinary text')),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: PageEditorView(
              repository: repo,
              pageId: page,
              title: 'Legacy',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      expect(state.document.root.children.first.delta!.toPlainText(), '');
      expect(
        state.document.root.children[2].delta!.toPlainText(),
        'Keep / path',
      );
      expect(state.document.root.children[3].delta!.toPlainText(), '/');
      // The repair uses the normal undo/save path rather than hiding rendered text.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await tester.pumpAndSettle();
      expect(
        (await repo.loadPageSnapshot(page)).document.root.children.first.delta!
            .toPlainText(),
        '',
      );
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await db.close();
    },
  );
}
