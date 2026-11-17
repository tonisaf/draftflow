import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';

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

  test('createDatabase creates database with default columns', () async {
    final dbId = await repo.createDatabase(title: 'Tasks & Projects', icon: '📋');
    final database = await repo.getDatabase(dbId);

    expect(database, isNotNull);
    expect(database!.title, 'Tasks & Projects');
    expect(database.icon, '📋');

    // Default columns: Name (title), Tags (select), Done (checkbox)
    final cols = await repo.getColumns(dbId);
    expect(cols.length, 3);
    expect(cols[0].name, 'Name');
    expect(cols[0].type, 'title');
    expect(cols[1].name, 'Tags');
    expect(cols[1].type, 'select');
    expect(cols[2].name, 'Done');
    expect(cols[2].type, 'checkbox');
  });

  test('addColumn, updateColumn, and deleteColumn manage properties correctly', () async {
    final dbId = await repo.createDatabase(title: 'Test DB');

    final colId = await repo.addColumn(
      dbId,
      name: 'Priority',
      type: 'select',
      width: 140.0,
    );

    var cols = await repo.getColumns(dbId);
    expect(cols.length, 4);
    final added = cols.firstWhere((c) => c.id == colId);
    expect(added.name, 'Priority');
    expect(added.width, 140.0);

    // Update column width and name
    await repo.updateColumn(colId, name: 'Urgency', width: 180.0);
    cols = await repo.getColumns(dbId);
    final updated = cols.firstWhere((c) => c.id == colId);
    expect(updated.name, 'Urgency');
    expect(updated.width, 180.0);

    // Delete column
    await repo.deleteColumn(colId);
    cols = await repo.getColumns(dbId);
    expect(cols.any((c) => c.id == colId), false);
  });

  test('createDatabaseRow creates page with properties, isolable from root active pages', () async {
    // 1. Create a regular root page
    final rootPageId = await repo.createPage(title: 'Regular Workspace Note');

    // 2. Create database and rows
    final dbId = await repo.createDatabase(title: 'Sprint 42');
    final rowId = await repo.createDatabaseRow(
      dbId,
      title: 'Fix Vibrancy Glitch',
      properties: {
        'priority': 'High',
        'points': 5,
        'done': false,
      },
    );

    // Verify row is retrieved via getDatabaseRows
    final rows = await repo.getDatabaseRows(dbId);
    expect(rows.length, 1);
    expect(rows.first.id, rowId);
    expect(rows.first.title, 'Fix Vibrancy Glitch');
    expect(rows.first.databaseId, dbId);

    // Verify properties JSON parsing
    final props = jsonDecode(rows.first.properties!) as Map<String, dynamic>;
    expect(props['priority'], 'High');
    expect(props['points'], 5);
    expect(props['done'], false);

    // Verify root sidebar pages ONLY contains root page, NOT the database row!
    final activePages = await repo.watchActivePages().first;
    expect(activePages.any((p) => p.id == rootPageId), true);
    expect(activePages.any((p) => p.id == rowId), false);

    // Verify row has initial page blocks and can be edited as a full document
    final doc = await repo.loadPageDocument(rowId);
    expect(doc.root.children.isNotEmpty, true);
  });

  test('replaceRowProperties and updateRowTitle modify record dynamically', () async {
    final dbId = await repo.createDatabase(title: 'Inventory');
    final rowId = await repo.createDatabaseRow(
      dbId,
      title: 'MacBook Pro',
      properties: {'stock': 10},
    );

    await repo.updateRowTitle(rowId, 'MacBook Pro M4 Max');
    await repo.replaceRowProperties(rowId, {'stock': 9, 'price': 3499});

    final row = await repo.getPage(rowId);
    expect(row!.title, 'MacBook Pro M4 Max');

    final props = jsonDecode(row.properties!) as Map<String, dynamic>;
    expect(props['stock'], 9);
    expect(props['price'], 3499);
  });

  test('deleteDatabasePermanently cascades to rows, blocks, and columns', () async {
    final dbId = await repo.createDatabase(title: 'Temporary DB');
    final row1 = await repo.createDatabaseRow(dbId, title: 'Item 1');
    final row2 = await repo.createDatabaseRow(dbId, title: 'Item 2');

    expect((await repo.getDatabaseRows(dbId)).length, 2);
    expect((await repo.getColumns(dbId)).isNotEmpty, true);

    await repo.deleteDatabasePermanently(dbId);

    // Database deleted
    expect(await repo.getDatabase(dbId), isNull);
    // Columns deleted
    expect(await repo.getColumns(dbId), isEmpty);
    // Rows deleted
    expect(await repo.getPage(row1), isNull);
    expect(await repo.getPage(row2), isNull);
    // Row blocks deleted
    expect((await db.getBlocksForPage(row1)), isEmpty);
    expect((await db.getBlocksForPage(row2)), isEmpty);
  });

  test('reorderColumn and moveColumnDirection reorder columns correctly', () async {
    final dbId = await repo.createDatabase(title: 'Reorder Columns DB');
    // Default columns: Name (title), Tags (select), Done (checkbox)
    final colAId = await repo.addColumn(dbId, name: 'ColA', type: 'text');
    final colBId = await repo.addColumn(dbId, name: 'ColB', type: 'number');

    var cols = await repo.getColumns(dbId);
    // Initial order: Name (0), Tags (1), Done (2), ColA (3), ColB (4)
    expect(cols.map((c) => c.name).toList(), [
      'Name',
      'Tags',
      'Done',
      'ColA',
      'ColB',
    ]);

    // 1. Move ColB left (from index 4 to index 3)
    await repo.moveColumnDirection(
      databaseId: dbId,
      columnId: colBId,
      moveLeft: true,
    );
    cols = await repo.getColumns(dbId);
    expect(cols.map((c) => c.name).toList(), [
      'Name',
      'Tags',
      'Done',
      'ColB',
      'ColA',
    ]);

    // 2. Reorder ColA to index 1 (right after Title)
    await repo.reorderColumn(
      databaseId: dbId,
      columnId: colAId,
      targetIndex: 1,
    );
    cols = await repo.getColumns(dbId);
    expect(cols.map((c) => c.name).toList(), [
      'Name',
      'ColA',
      'Tags',
      'Done',
      'ColB',
    ]);

    // 3. Title column cannot be moved or replaced
    await repo.moveColumnDirection(
      databaseId: dbId,
      columnId: colAId,
      moveLeft: true,
    );
    cols = await repo.getColumns(dbId);
    // Index 1 cannot move left past title
    expect(cols.first.name, 'Name');
    expect(cols[1].name, 'ColA');
  });
}
