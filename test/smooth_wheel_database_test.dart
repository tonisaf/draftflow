import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/common/app_scroll_behavior.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/ui/editor/components/smooth_page_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  testWidgets(
    'real database rows smooth both axes without scrolling the page',
    (t) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = NotesRepository(db);
      final database = await repo.createDatabase(title: 'Wheel table');
      final columns = await repo.getColumns(database);
      for (final col in columns) {
        await repo.updateColumn(col.id, width: 400);
      }
      for (var i = 0; i < 35; i++) {
        await repo.createDatabaseRow(database, title: 'Row $i');
      }
      final editor = EditorState(
        document: Document(
          root: pageNode(
            children: [
              databaseBlockNode(databaseId: database, title: 'Wheel table'),
              for (var i = 0; i < 40; i++) paragraphNode(text: 'Paragraph $i'),
            ],
          ),
        ),
      );
      final scroll = EditorScrollController(editorState: editor);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light)
              .copyWith(platform: TargetPlatform.windows),
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: AppFlowyEditor(
              editorState: editor,
              editorScrollController: scroll,
              editorStyle: EditorStyle.desktop(),
              blockComponentBuilders: {
                ...standardBlockComponentBuilderMap,
                PageBlockKeys.type: SmoothPageBlockComponentBuilder(),
                databaseBlockType: DatabaseBlockComponentBuilder(
                  repository: repo,
                ),
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final viewport = find.byKey(const Key('database_rows_viewport'));
      final vertical = t
          .state<ScrollableState>(
            find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      final horizontal = t
          .widgetList<SingleChildScrollView>(
            find.descendant(
              of: find.byType(DatabaseBlockComponentWidget),
              matching: find.byType(SingleChildScrollView),
            ),
          )
          .firstWhere((w) => w.scrollDirection == Axis.horizontal)
          .controller!;
      final point = t.getTopLeft(viewport) + const Offset(140, 18);
      Future<void> wheel(Offset delta) => t.sendEventToBinding(
        PointerScrollEvent(
          position: point,
          scrollDelta: delta,
          kind: PointerDeviceKind.mouse,
        ),
      );
      await wheel(const Offset(0, 100));
      expect(vertical.pixels, 0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 35));
      expect(vertical.pixels, inExclusiveRange(0, 100));
      await wheel(const Offset(0, 80));
      await t.pumpAndSettle();
      expect(vertical.pixels, closeTo(180, 0.1));
      await wheel(const Offset(120, 0));
      expect(horizontal.offset, 0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 35));
      expect(horizontal.offset, inExclusiveRange(0, 120));
      await wheel(const Offset(100, 0));
      await t.pumpAndSettle();
      expect(horizontal.offset, closeTo(220, 0.1));
      expect(vertical.pixels, closeTo(180, 0.1));
      expect(scroll.offsetNotifier.value, closeTo(0, 0.1));
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      scroll.dispose();
      editor.dispose();
      await db.close();
      expect(t.takeException(), isNull);
    },
  );
}
