import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/model/database_initial_data.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/ui/editor/page_editor_view.dart';
import 'package:notes_here/ui/theme.dart';

class DelayedPreviewRepository extends NotesRepository {
  DelayedPreviewRepository(super.db);
  final gate = Completer<void>();
  final started = Completer<void>();
  DatabaseInitialData? loaded;
  @override
  Future<DatabaseInitialData> loadDatabaseInitialData(String id) async {
    loaded = await super.loadDatabaseInitialData(id);
    if (!started.isCompleted) started.complete();
    await gate.future;
    return loaded!;
  }
}

void main() {
  testWidgets(
    'first visible document has its bounded table rows and following text never jumps',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DelayedPreviewRepository(db);
      final page = await repo.createPage(title: 'Stable page');
      final database = await repo.createDatabase(
        parentPageId: page,
        title: 'Stable table',
      );
      for (var i = 0; i < 60; i++) {
        await repo.createDatabaseRow(database, title: 'Row $i');
      }
      await repo.savePageNodes(page, [
        databaseBlockNode(databaseId: database),
        paragraphNode(delta: Delta()..insert('Following paragraph')),
      ]);
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: PageEditorView(
                repository: repo,
                pageId: page,
                title: 'Stable page',
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => repo.started.future);
      await tester.pump();
      expect(repo.started.isCompleted, isTrue);
      expect(find.byType(AppFlowyEditor), findsNothing);
      expect(find.text('0 items'), findsNothing);
      expect(repo.loaded!.rows.rows.length, DatabaseQueryPolicy.pageSize);
      expect(repo.loaded!.rows.totalCount, 60);
      repo.gate.complete();
      // Check each frame, rather than only the settled result that used to hide
      // the briefly empty table and its shift of following document blocks.
      Offset? position;
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump();
        if (find.byType(AppFlowyEditor).evaluate().isEmpty) continue;
        expect(find.text('60 items'), findsOneWidget);
        expect(find.text('0 items'), findsNothing);
        final paragraph = find.text('Following paragraph', findRichText: true);
        expect(paragraph, findsOneWidget);
        final current = tester.getTopLeft(paragraph);
        position ??= current;
        expect(current, position);
      }
      expect(position, isNotNull);
      await repo.createDatabaseRow(database, title: 'New live row');
      await tester.pumpAndSettle();
      expect(find.text('61 items'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Following paragraph', findRichText: true)),
        position,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(null);
      await db.close();
    },
  );

  testWidgets(
    'a late table preview cannot replace a different page after navigation',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = DelayedPreviewRepository(db);
      final first = await repo.createPage(title: 'First');
      final second = await repo.createPage(title: 'Second');
      final database = await repo.createDatabase(parentPageId: first);
      await repo.savePageNodes(first, [
        databaseBlockNode(databaseId: database),
      ]);
      final selected = ValueNotifier(first);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: selected,
              builder: (_, id, _) => PageEditorView(
                repository: repo,
                pageId: id,
                title: id == first ? 'First' : 'Second',
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => repo.started.future);
      await tester.pump();
      expect(repo.started.isCompleted, true);
      selected.value = second;
      await tester.pumpAndSettle();
      repo.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DatabaseBlockComponentWidget), findsNothing);
      expect(find.widgetWithText(TextField, 'Second'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      selected.dispose();
      await db.close();
    },
  );
}
