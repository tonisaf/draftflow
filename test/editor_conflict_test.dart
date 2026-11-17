import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  testWidgets(
    'external writes show a conflict and preserve editor and selection',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      addTearDown(db.close);
      final pageId = await repo.createPage();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: PageEditorView(
              repository: repo,
              pageId: pageId,
              title: 'Note',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      await repo.savePageNodes(pageId, [paragraphNode(text: 'External')]);
      final selection = Selection.collapsed(Position(path: [0], offset: 5));
      await state.apply(
        state.transaction
          ..insertText(state.document.root.children.first, 0, 'Local')
          ..afterSelection = selection,
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Conflict — draft kept locally'), findsOneWidget);
      expect(
        tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor)).editorState,
        same(state),
      );
      expect(state.selection, selection);
      expect(state.document.root.children.first.delta!.toPlainText(), 'Local');
      expect(
        (await repo.loadPageDocument(pageId)).root.children.first.delta!
            .toPlainText(),
        'External',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final useLocal in [true, false]) {
    testWidgets(
      'restored draft can be compared and resolved with ${useLocal ? 'local' : 'saved'} version',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = NotesRepository(db);
        final pageId = await repo.createPage();
        final base = await repo.loadPageSnapshot(pageId);
        await repo.saveDraft('recovered', pageId, base.version, [
          paragraphNode(text: 'Recovered local text'),
        ]);
        await repo.savePageNodes(pageId, [
          paragraphNode(text: 'Current saved text'),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: PageEditorView(
                repository: repo,
                pageId: pageId,
                title: 'Note',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState;
        expect(
          state.document.root.children.single.delta!.toPlainText(),
          'Recovered local text',
        );
        await tester.tap(find.text('Compare versions'));
        await tester.pumpAndSettle();
        expect(find.text('Local draft'), findsOneWidget);
        expect(find.text('Saved version'), findsOneWidget);
        expect(find.text('Current saved text'), findsOneWidget);
        await tester.tap(find.text('Decide later'));
        await tester.pumpAndSettle();
        expect((await repo.getDrafts(pageId)).isNotEmpty, isTrue);
        await tester.tap(find.text('Compare versions'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(useLocal ? 'Use local draft' : 'Use saved version'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Resolve document conflict'), findsNothing);
        expect(find.text('Compare versions'), findsNothing);
        expect(await repo.getDrafts(pageId), isEmpty);
        final resolved = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState;
        expect(
          resolved.document.root.children.single.delta!.toPlainText(),
          useLocal ? 'Recovered local text' : 'Current saved text',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(await repo.getDrafts(pageId), isEmpty);
      },
    );
  }
}
