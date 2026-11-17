import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/ui/editor/components/database/database_cells.dart';
import 'package:notes_here/ui/theme.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  late String databaseId;
  late String firstColumn;
  late String secondColumn;
  late String rowId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
    databaseId = await repo.createDatabase();
    firstColumn = await repo.addColumn(databaseId, name: 'First', type: 'text');
    secondColumn = await repo.addColumn(
      databaseId,
      name: 'Second',
      type: 'text',
    );
    rowId = await repo.createDatabaseRow(
      databaseId,
      properties: {firstColumn: 'A old', secondColumn: 'B old', 'legacy': 42},
    );
  });
  tearDown(() => db.close());

  Future<Map<String, dynamic>> properties() async =>
      jsonDecode((await repo.getPage(rowId))!.properties!)
          as Map<String, dynamic>;

  test(
    'concurrent patches preserve independent column changes and legacy keys',
    () async {
      final otherEditor = NotesRepository(db);
      await Future.wait([
        repo.patchRowProperties(rowId, {firstColumn: 'A new'}),
        otherEditor.patchRowProperties(rowId, {secondColumn: 'B new'}),
      ]);
      expect(await properties(), {
        firstColumn: 'A new',
        secondColumn: 'B new',
        'legacy': 42,
      });
    },
  );

  test(
    'null, false, zero and arrays are values; omitted properties are preserved',
    () async {
      await repo.patchRowProperties(rowId, {firstColumn: null});
      expect(await properties(), {
        firstColumn: null,
        secondColumn: 'B old',
        'legacy': 42,
      });
      await repo.patchRowProperties(rowId, {
        firstColumn: ['one', 'two'],
        secondColumn: false,
      });
      await repo.patchRowProperties(rowId, {firstColumn: [], secondColumn: 0});
      final before = await properties();
      await repo.patchRowProperties(rowId, {});
      expect(await properties(), before);
      expect(before, {firstColumn: [], secondColumn: 0, 'legacy': 42});
    },
  );

  test('a foreign or title column rejects the entire patch', () async {
    final foreignDatabase = await repo.createDatabase();
    final foreignColumn = await repo.addColumn(
      foreignDatabase,
      name: 'Foreign',
      type: 'text',
    );
    final titleColumn = (await repo.getColumns(databaseId)).first.id;
    for (final invalid in [foreignColumn, titleColumn, 'missing']) {
      await expectLater(
        repo.patchRowProperties(rowId, {firstColumn: 'Changed', invalid: 'No'}),
        throwsArgumentError,
      );
      expect((await properties())[firstColumn], 'A old');
    }
  });

  test('missing, ordinary and trashed pages cannot be patched', () async {
    final ordinaryPage = await repo.createPage();
    await repo.trashPage(rowId);
    for (final id in ['missing', ordinaryPage, rowId]) {
      await expectLater(
        repo.patchRowProperties(id, {firstColumn: 'No'}),
        throwsStateError,
      );
    }
    expect((await properties())[firstColumn], 'A old');
  });

  test('malformed properties are not silently replaced', () async {
    await db.replaceRowProperties(rowId, '[]');
    await expectLater(
      repo.patchRowProperties(rowId, {firstColumn: 'No'}),
      throwsFormatException,
    );
    expect((await repo.getPage(rowId))!.properties, '[]');
  });

  test('a failed write rolls back all properties', () async {
    final before = await properties();
    await db.customStatement('''
      CREATE TRIGGER reject_properties BEFORE UPDATE OF properties ON pages
      BEGIN SELECT RAISE(ABORT, 'Injected failure'); END
    ''');
    await expectLater(
      repo.patchRowProperties(rowId, {
        firstColumn: 'A new',
        secondColumn: 'B new',
      }),
      throwsA(isA<SqliteException>()),
    );
    expect(await properties(), before);
  });

  testWidgets(
    'cells rendered from a stale row send only their changed property',
    (tester) async {
      final staleRow = (await repo.getPage(rowId))!;
      final columns = (await repo.getColumns(databaseId))
          .where((c) => c.id == firstColumn || c.id == secondColumn)
          .toList();
      final patches = <Map<String, dynamic>>[];
      final writes = <Future<void>>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: DataRowView(
              page: staleRow,
              columns: columns,
              columnWidths: const {},
              borderColor: Skin.of(Brightness.light).divider,
              isEven: false,
              repository: repo,
              onOpenPage: () {},
              onUpdateTitle: (_) {},
              onDeleteRow: () {},
              onPatchProperties: (patch) {
                patches.add(patch);
                writes.add(repo.patchRowProperties(rowId, patch));
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'A old'), 'A new');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'B old'), 'B new');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.wait(writes);
      expect(patches, [
        {firstColumn: 'A new'},
        {secondColumn: 'B new'},
      ]);
      expect(await properties(), {
        firstColumn: 'A new',
        secondColumn: 'B new',
        'legacy': 42,
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
