import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = NotesRepository(db);
    await repo.createPage(title: 'Welcome Note');

    await tester.pumpWidget(NotesApp(repository: repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome Note'), findsWidgets);

    // Unmount and flush zero-duration cleanup timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
