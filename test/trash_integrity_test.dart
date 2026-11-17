import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/export_import_service.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });
  tearDown(() => db.close());

  Future<
    ({String root, String child, String database, String row, String nested})
  >
  workspace() async {
    final root = await repo.createPage(title: 'Root');
    final child = await repo.createPage(title: 'Child', parentId: root);
    final database = await repo.createDatabase(parentPageId: child);
    final row = await repo.createDatabaseRow(database, title: 'Row');
    final nested = await repo.createDatabase(parentPageId: row);
    await repo.createDatabaseRow(nested, title: 'Nested row');
    await repo.saveDraft(
      'draft',
      row,
      (await repo.loadPageSnapshot(row)).version,
      [paragraphNode(text: 'Draft')],
    );
    return (
      root: root,
      child: child,
      database: database,
      row: row,
      nested: nested,
    );
  }

  test('trash and restore cascade through pages, embedded databases, rows and blocks', () async {
    final w = await workspace();
    final unrelated = await repo.createPage(title: 'Unrelated');
    await repo.trashPage(w.root);
    final trashedPages = (await db.getAllPages())
        .where((p) => p.id != unrelated)
        .toList();
    expect(trashedPages.every((p) => p.trashedAt != null), isTrue);
    expect(trashedPages.map((p) => p.trashBatchId).toSet().length, 1);
    expect(
      (await db.getAllDatabases()).every((d) => d.trashedAt != null),
      isTrue,
    );
    expect(
      (await db.getAllBlocks())
          .where((b) => b.pageId != unrelated)
          .every((b) => b.trashedAt != null),
      isTrue,
    );
    expect(await repo.getDrafts(w.row), hasLength(1));
    await repo.restorePage(w.root);
    expect(
      (await db.getAllPages()).every(
        (p) => p.trashedAt == null && p.trashBatchId == null,
      ),
      isTrue,
    );
    expect(
      (await db.getAllDatabases()).every((d) => d.trashedAt == null),
      isTrue,
    );
    expect((await db.getAllBlocks()).every((b) => b.trashedAt == null), isTrue);
  });

  test('previously trashed pages, databases, rows and blocks stay in trash on parent restore', () async {
    final w = await workspace();
    final oldPage = await repo.createPage(parentId: w.root);
    await repo.trashPage(oldPage);
    final oldRow = await repo.createDatabaseRow(w.database);
    await repo.deleteDatabaseRow(oldRow);
    final oldDb = await repo.createDatabase(parentPageId: w.child);
    await repo.trashDatabase(oldDb);
    final blockId = (await db.getBlocksForPage(w.child)).single.id;
    await (db.update(db.blocks)..where((t) => t.id.equals(blockId))).write(
      BlocksCompanion(trashedAt: drift.Value(DateTime(2020))),
    );
    final oldBatch = (await repo.getPage(oldPage))!.trashBatchId;
    await repo.trashPage(w.root);
    final batch = (await repo.getPage(w.root))!.trashBatchId;
    await repo.trashPage(w.root); // Repeated deletion is idempotent.
    expect((await repo.getPage(w.root))!.trashBatchId, batch);
    await repo.restorePage(w.root);
    expect((await repo.getPage(oldPage))!.trashBatchId, oldBatch);
    expect((await repo.getPage(oldRow))!.trashedAt, isNotNull);
    expect((await repo.getDatabase(oldDb))!.trashedAt, isNotNull);
    expect(
      (await db.getAllBlocks()).firstWhere((b) => b.id == blockId).trashedAt,
      isNotNull,
    );
    expect((await repo.getPage(w.row))!.trashedAt, isNull);
  });

  test('restoring a nested row restores its required ancestors', () async {
    final w = await workspace();
    await repo.trashPage(w.root);
    await repo.restorePage(w.row);
    expect((await repo.getPage(w.root))!.trashedAt, isNull);
    expect((await repo.getPage(w.child))!.trashedAt, isNull);
    expect((await repo.getDatabase(w.database))!.trashedAt, isNull);
    expect((await repo.getPage(w.row))!.trashedAt, isNull);
  });

  test(
    'permanent page deletion removes the complete ownership tree and drafts',
    () async {
      final w = await workspace();
      final oldRow = await repo.createDatabaseRow(w.database);
      await repo.trashPage(oldRow);
      final unrelated = await repo.createPage();
      await repo.permanentlyDeletePage(w.root);
      expect((await db.getAllPages()).map((p) => p.id), [unrelated]);
      expect(await db.getAllDatabases(), isEmpty);
      expect(await db.getAllDatabaseColumns(), isEmpty);
      expect(
        (await db.getAllBlocks()).every((b) => b.pageId == unrelated),
        isTrue,
      );
      expect(await repo.getDrafts(w.row), isEmpty);
      await expectLater(
        repo.saveDraft('late', w.row, '', [paragraphNode(text: 'Late')]),
        throwsStateError,
      );
    },
  );

  test('permanent database deletion also removes trashed rows and their nested content', () async {
    final w = await workspace();
    await repo.deleteDatabaseRow(w.row);
    await repo.deleteDatabasePermanently(w.database);
    expect(await repo.getPage(w.row), isNull);
    expect(await repo.getDatabase(w.nested), isNull);
    expect(await repo.getDrafts(w.row), isEmpty);
    expect(await db.getAllDatabaseColumns(), isEmpty);
    expect(await repo.getPage(w.child), isNotNull);
  });

  test('empty trash includes standalone databases without deleting active siblings', () async {
    final w = await workspace();
    final standalone = await repo.createDatabase();
    await repo.createDatabaseRow(standalone);
    await repo.trashDatabase(standalone);
    await repo.deleteDatabaseRow(w.row);
    await repo.emptyTrash();
    expect(await repo.getDatabase(standalone), isNull);
    expect(await repo.getPage(w.row), isNull);
    expect(await repo.getDatabase(w.nested), isNull);
    expect((await repo.getDatabase(w.database))!.trashedAt, isNull);
    expect(await repo.getPage(w.root), isNotNull);
  });

  for (final operation in ['trash', 'restore', 'delete', 'empty']) {
    test('$operation rolls back the entire tree on a database error', () async {
      final w = await workspace();
      if (operation == 'restore' || operation == 'empty') {
        await repo.trashPage(w.root);
      }
      final before = await ExportImportService(repository: repo)
          .exportWorkspaceJson();
      final draftsBefore = await repo.getDrafts(w.row);
      final sqlOperation = operation == 'delete' || operation == 'empty'
          ? 'DELETE'
          : 'UPDATE';
      await db.customStatement('''
        CREATE TRIGGER reject_database_change BEFORE $sqlOperation ON databases
        BEGIN SELECT RAISE(ABORT, 'Injected failure'); END
      ''');
      await expectLater(switch (operation) {
        'trash' => repo.trashPage(w.root),
        'restore' => repo.restorePage(w.root),
        'delete' => repo.permanentlyDeletePage(w.root),
        _ => repo.emptyTrash(),
      }, throwsA(isA<SqliteException>()));
      final after = await ExportImportService(repository: repo)
          .exportWorkspaceJson();
      // Ignore the timestamp added by export; all persisted entity data must match.
      expect(
        after.substring(after.indexOf('"pages"')),
        before.substring(before.indexOf('"pages"')),
      );
      expect(await repo.getDrafts(w.row), draftsBefore);
    });
  }

  test('backup roundtrip preserves deletion groups', () async {
    final w = await workspace();
    final oldRow = await repo.createDatabaseRow(w.database);
    await repo.deleteDatabaseRow(oldRow);
    await repo.trashPage(w.root);
    final service = ExportImportService(repository: repo);
    final backup = await service.exportWorkspaceJson();
    await service.restoreWorkspaceJson(backup, wipeExisting: true);
    await repo.restorePage(w.root);
    expect((await repo.getPage(w.row))!.trashedAt, isNull);
    expect((await repo.getPage(oldRow))!.trashedAt, isNotNull);
  });

  test('permanent deletion respects enabled SQLite foreign keys', () async {
    await db.customStatement('PRAGMA foreign_keys = ON');
    final w = await workspace();
    await repo.trashPage(w.row);
    await repo.permanentlyDeletePage(w.root);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(await db.getAllPages(), isEmpty);
  });

  test('linked database references do not transfer ownership', () async {
    final root = await repo.createPage();
    final owner = await repo.createPage();
    final database = await repo.createDatabase(parentPageId: owner);
    final row = await repo.createDatabaseRow(database);
    await repo.savePageNodes(root, [
      Node(type: 'database', attributes: {'databaseId': database}),
    ]);
    await repo.permanentlyDeletePage(root);
    expect(await repo.getDatabase(database), isNotNull);
    expect(await repo.getPage(row), isNotNull);
  });

  test(
    'large subtrees are processed without exceeding SQL parameter limits',
    () async {
      final root = await repo.createPage();
      await db.batch((batch) {
        batch.insertAll(db.pages, [
          for (var i = 0; i < 825; i++)
            PagesCompanion(
              id: drift.Value('child-$i'),
              parentId: drift.Value(root),
            ),
        ]);
      });
      await repo.trashPage(root);
      expect(await repo.watchTrashedPages().first, hasLength(826));
      await repo.restorePage(root);
      expect(await repo.watchActivePages().first, hasLength(826));
      await repo.permanentlyDeletePage(root);
      expect(await db.getAllPages(), isEmpty);
    },
  );

  test('schema 6 migration preserves data and existing drafts', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp(
      'notes_here_trash_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/notes.sqlite');
    var disk = AppDatabase(NativeDatabase(file));
    var repository = NotesRepository(disk);
    final id = await repository.createPage();
    await repository.saveDraft('draft', id, '', [paragraphNode(text: 'Draft')]);
    for (final table in ['pages', 'blocks', 'databases']) {
      await disk.customStatement(
        'ALTER TABLE $table DROP COLUMN trash_batch_id',
      );
    }
    for (final index in [
      'pages_database_order',
      'pages_parent_order',
      'blocks_page_order',
      'database_columns_order',
    ]) {
      await disk.customStatement('DROP INDEX $index');
    }
    await disk.customStatement('ALTER TABLE pages DROP COLUMN title_folded');
    await disk.customStatement(
      'ALTER TABLE pages DROP COLUMN properties_folded',
    );
    await disk.customStatement('PRAGMA user_version = 6');
    await disk.close();
    disk = AppDatabase(NativeDatabase(file));
    repository = NotesRepository(disk);
    await repository.trashPage(id);
    expect((await repository.getPage(id))!.trashBatchId, isNotNull);
    expect(await repository.getDrafts(id), hasLength(1));
    await disk.close();
  });
}
