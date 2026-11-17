import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database_block_component.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });
  tearDown(() async {
    await db.close();
  });

  Future<EditorState> mount(WidgetTester tester) async {
    final id = await repo.createDatabase(title: 'Inline table');
    final state = EditorState(
      document: Document(
        root: pageNode(children: [databaseBlockNode(databaseId: id)]),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: AppFlowyEditor(
            editorState: state,
            blockComponentBuilders: {
              ...standardBlockComponentBuilderMap,
              databaseBlockType: DatabaseBlockComponentBuilder(
                repository: repo,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets(
    'text can be inserted on both sides and repeated clicks reuse paragraphs',
    (tester) async {
      final state = await mount(tester);
      await tester.tap(find.byKey(const ValueKey('database_text_before')));
      await tester.pumpAndSettle();
      expect(state.document.root.children.map((n) => n.type), [
        'paragraph',
        databaseBlockType,
      ]);
      expect(state.selection?.start.path, [0]);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('Before table');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('database_text_after')));
      await tester.pumpAndSettle();
      expect(state.document.root.children.map((n) => n.type), [
        'paragraph',
        databaseBlockType,
        'paragraph',
      ]);
      expect(state.selection?.start.path, [2]);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.enterText('After table');
      await tester.pumpAndSettle();
      expect(
        state.document.root.children.first.delta!.toPlainText(),
        'Before table',
      );
      expect(
        state.document.root.children.last.delta!.toPlainText(),
        'After table',
      );
      // Repeated clicks focus the existing paragraph without adding blank blocks.
      await tester.tap(find.byKey(const ValueKey('database_text_before')));
      await tester.pumpAndSettle();
      expect(state.document.root.children.length, 3);
      expect(state.selection?.start.path, [0]);
      expect(state.selection?.start.offset, 'Before table'.length);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'add property selects its type in a dropdown and persists without a dialog',
    (tester) async {
      final state = await mount(tester);
      final id =
          state.document.root.children.single.attributes['databaseId']
              as String;
      await tester.tap(find.byTooltip('Add property'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('database_property_name')),
        'Estimate',
      );
      await tester.tap(find.byType(ModernSelectPicker<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add property'));
      await tester.pumpAndSettle();
      final column = (await repo.getColumns(id))
          .firstWhere((c) => c.name == 'Estimate');
      expect(column.type, 'number');
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
