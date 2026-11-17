import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/common/quick_search_dialog.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);

    await repo.createPage(title: 'Engineering Specs');
    await repo.createPage(title: 'Marketing Roadmap');
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('QuickSearchDialog displays pages and allows opening one', (tester) async {
    QuickSearchResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showQuickSearchDialog(context, repository: repo);
              },
              child: const Text('Open Search'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT PAGES'), findsOneWidget);
    expect(find.text('Engineering Specs'), findsOneWidget);
    expect(find.text('Marketing Roadmap'), findsOneWidget);

    // Tap on Marketing Roadmap
    await tester.tap(find.text('Marketing Roadmap'));
    await tester.pumpAndSettle();

    expect(result, isA<OpenPageResult>());
  });

  testWidgets('QuickSearchDialog shows create option when query has no exact match', (tester) async {
    QuickSearchResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showQuickSearchDialog(context, repository: repo);
              },
              child: const Text('Open Search'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Search'));
    await tester.pumpAndSettle();

    // Enter non-existing title in search field
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'New Feature Idea');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.textContaining('Create page "New Feature Idea"'), findsOneWidget);

    await tester.tap(find.textContaining('Create page "New Feature Idea"'));
    await tester.pumpAndSettle();

    expect(result, isA<CreatePageResult>());
    expect((result as CreatePageResult).title, 'New Feature Idea');
  });
}
