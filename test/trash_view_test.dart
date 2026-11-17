import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/common/modern_dialog.dart';
import 'package:notes_here/ui/theme.dart';
import 'package:notes_here/ui/trash/trash_view.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'TrashView displays deleted pages and confirms empty trash via ModernDialog',
    (tester) async {
      final pageId = await repository.createPage(title: 'Page in Trash');
      await repository.trashPage(pageId);
      expect((await repository.watchTrashEntries().first).single.id, pageId);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: TrashView(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page in Trash'), findsOneWidget);
      expect(find.text('Empty Trash'), findsOneWidget);

      // Tap "Empty Trash" button
      await tester.tap(find.text('Empty Trash'));
      await tester.pumpAndSettle();

      // Verify ModernDialog opens
      expect(find.byType(ModernDialog), findsOneWidget);
      expect(find.text('Empty Trash?'), findsOneWidget);
      expect(
        find.text(
          'All pages, databases, rows and blocks in the trash will be permanently erased. This action cannot be undone.',
        ),
        findsOneWidget,
      );

      // Cancel first
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ModernDialog), findsNothing);

      // Still in trash
      expect(find.text('Page in Trash'), findsOneWidget);

      // Tap "Empty Trash" again and confirm
      await tester.tap(find.text('Empty Trash'));
      await tester.pumpAndSettle();

      // Find the confirm button inside ModernDialog actions
      final confirmBtn = find.descendant(
        of: find.byType(ModernDialog),
        matching: find.text('Empty Trash'),
      );
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dialog dismissed and trash is empty
      expect(find.byType(ModernDialog), findsNothing);
      expect(find.text('Trash is empty'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'trashed databases and rows can be restored through the trash UI',
    (tester) async {
      final database = await repository.createDatabase(
        title: 'Deleted database',
      );
      final row = await repository.createDatabaseRow(
        database,
        title: 'Deleted row',
      );
      await repository.trashDatabase(database);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: TrashView(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deleted database'), findsNWidgets(2));
      expect(find.text('Deleted row'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('trash_restore_database:$database')),
      );
      await tester.pumpAndSettle();
      expect((await repository.getDatabase(database))!.trashedAt, isNull);
      expect((await repository.getPage(row))!.trashedAt, isNull);
      expect(find.text('Trash is empty'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
