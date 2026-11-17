import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/common/page_link_picker_dialog.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);

    await repo.createPage(title: 'Design System');
    await repo.createPage(title: 'Release Checklist');
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('PageLinkPickerDialog displays pages, filters out excludePageId, and selects target page', (tester) async {
    final allPages = await db.getAllPages();
    final designSystem = allPages.firstWhere((p) => p.title == 'Design System');
    final checklist = allPages.firstWhere((p) => p.title == 'Release Checklist');

    Page? pickedPage;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                pickedPage = await showPageLinkPickerDialog(
                  context,
                  repository: repo,
                  excludePageId: designSystem.id,
                );
              },
              child: const Text('Open Page Link Picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Page Link Picker'));
    await tester.pumpAndSettle();

    // Design System should be excluded
    expect(find.text('Design System'), findsNothing);
    // Release Checklist should be visible
    expect(find.text('Release Checklist'), findsOneWidget);

    // Tap Release Checklist
    await tester.tap(find.text('Release Checklist'));
    await tester.pumpAndSettle();

    expect(pickedPage, isNotNull);
    expect(pickedPage!.id, checklist.id);
  });
}
