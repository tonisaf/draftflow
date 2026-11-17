import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/auto_save_service.dart';
import 'package:notes_here/services/export_import_service.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotesRepository(db);
  });
  tearDown(() => db.close());

  Future<void> auditWrites() async {
    await db.customStatement(
      'CREATE TABLE block_writes (operation TEXT, block_id TEXT)',
    );
    for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
      final row = operation == 'DELETE' ? 'OLD' : 'NEW';
      await db.customStatement(
        '''CREATE TRIGGER audit_${operation.toLowerCase()} AFTER $operation ON blocks
        BEGIN INSERT INTO block_writes VALUES ('$operation', $row.id); END''',
      );
    }
  }

  Future<List<(String, String)>> writes() async =>
      (await db
              .customSelect('SELECT operation, block_id FROM block_writes')
              .get())
          .map(
            (row) =>
                (row.read<String>('operation'), row.read<String>('block_id')),
          )
          .toList();

  test(
    'unchanged save makes no block writes and preserves version and all IDs',
    () async {
      final id = await repo.createPage();
      await repo.savePageNodes(id, [
        Node(
          type: 'bulleted_list',
          children: [paragraphNode(text: 'Nested')],
        ),
      ]);
      final snapshot = await repo.loadPageSnapshot(id);
      final before = await db.getBlocksForPage(id);
      await auditWrites();
      final version = await repo.savePageNodes(
        id,
        snapshot.document.root.children,
        expectedVersion: snapshot.version,
      );
      expect(await writes(), isEmpty);
      expect(version, snapshot.version);
      expect(await db.getBlocksForPage(id), before);
      final reloaded = await repo.loadPageDocument(id);
      expect(
        reloaded.root.children.first.children.first.id,
        snapshot.document.root.children.first.children.first.id,
      );
    },
  );

  test('editing one of 1000 blocks updates exactly that row', () async {
    final id = await repo.createPage();
    await repo.savePageNodes(
      id,
      List.generate(1000, (i) => paragraphNode(text: 'Block $i')),
    );
    final nodes = (await repo.loadPageDocument(id)).root.children;
    final before = {for (final b in await db.getBlocksForPage(id)) b.id: b};
    nodes[500].updateAttributes({
      'delta': (Delta()..insert('Edited')).toJson(),
    });
    await auditWrites();
    await repo.savePageNodes(id, nodes);
    expect(await writes(), [('UPDATE', nodes[500].id)]);
    for (final row in await db.getBlocksForPage(id)) {
      expect(row.orderKey, before[row.id]!.orderKey);
      if (row.id != nodes[500].id) expect(row, before[row.id]);
    }
  });

  for (final moveToStart in [true, false]) {
    test(
      'moving one block ${moveToStart ? 'to start' : 'to end'} changes one order key',
      () async {
        final id = await repo.createPage();
        await repo.savePageNodes(
          id,
          List.generate(100, (i) => paragraphNode(text: '$i')),
        );
        final nodes = (await repo.loadPageDocument(id)).root.children.toList();
        final before = {for (final b in await db.getBlocksForPage(id)) b.id: b};
        final moved = nodes.removeAt(moveToStart ? nodes.length - 1 : 0);
        nodes.insert(moveToStart ? 0 : nodes.length, moved);
        await auditWrites();
        await repo.savePageNodes(id, nodes);
        expect(await writes(), [('UPDATE', moved.id)]);
        final after = await db.getBlocksForPage(id);
        expect(after.map((b) => b.id), nodes.map((n) => n.id));
        for (final b in after) {
          expect(b.content, before[b.id]!.content);
          if (b.id != moved.id) expect(b.orderKey, before[b.id]!.orderKey);
        }
      },
    );
  }

  test('inserting a run preserves neighbour keys and deletion removes only absent rows', () async {
    final id = await repo.createPage();
    await repo.savePageNodes(id, [
      paragraphNode(text: 'A'),
      paragraphNode(text: 'B'),
    ]);
    final nodes = (await repo.loadPageDocument(id)).root.children.toList();
    final before = await db.getBlocksForPage(id);
    final added = [paragraphNode(text: 'X'), paragraphNode(text: 'Y')];
    nodes.insertAll(1, added);
    await auditWrites();
    await repo.savePageNodes(id, nodes);
    expect(await writes(), added.map((n) => ('INSERT', n.id)).toList());
    final after = await db.getBlocksForPage(id);
    expect(after.first.orderKey, before.first.orderKey);
    expect(after.last.orderKey, before.last.orderKey);
    expect(after.map((b) => b.id), nodes.map((n) => n.id));
    await db.customStatement('DELETE FROM block_writes');
    nodes.removeAt(1);
    await repo.savePageNodes(id, nodes);
    expect(await writes(), [('DELETE', added.first.id)]);
  });

  test(
    'autosaving a nested edit updates only the leaf and preserves ancestor IDs',
    () async {
      final id = await repo.createPage();
      await repo.savePageNodes(id, [
        Node(
          type: 'bulleted_list',
          children: [paragraphNode(text: 'Leaf')],
        ),
      ]);
      final snapshot = await repo.loadPageSnapshot(id);
      final editor = EditorState(document: snapshot.document);
      final leaf = editor.document.root.children.first.children.single;
      final before = {for (final b in await db.getBlocksForPage(id)) b.id: b};
      final service = AutoSaveService(
        repository: repo,
        pageId: id,
        editorState: editor,
        initialVersion: snapshot.version,
        debounceDuration: const Duration(days: 1),
      );
      await editor.apply(editor.transaction..insertText(leaf, 4, ' edited'));
      await auditWrites();
      await service.forceSave();
      service.dispose();
      expect(await writes(), [('UPDATE', leaf.id)]);
      final restored = await repo.loadPageDocument(id);
      expect(restored.root.children.first.children.single.id, leaf.id);
      expect(
        restored.root.children.first.children.single.delta!.toPlainText(),
        'Leaf edited',
      );
      for (final b in await db.getBlocksForPage(id)) {
        expect(b.orderKey, before[b.id]!.orderKey);
        if (b.id != leaf.id) expect(b, before[b.id]);
      }
    },
  );

  test('reparenting a subtree updates only its root row', () async {
    final id = await repo.createPage();
    final leaf = paragraphNode(text: 'Leaf');
    final subtree = Node(type: 'bulleted_list', children: [leaf]);
    final first = Node(type: 'bulleted_list', children: [subtree]);
    final second = paragraphNode(text: 'Second');
    await repo.savePageNodes(id, [first, second]);
    final replacementFirst = Node(type: first.type, id: first.id);
    final replacementSecond = Node(
      type: second.type,
      id: second.id,
      attributes: second.attributes,
      children: [subtree],
    );
    await auditWrites();
    await repo.savePageNodes(id, [replacementFirst, replacementSecond]);
    expect(await writes(), [('UPDATE', subtree.id)]);
    final restored = await repo.loadPageDocument(id);
    expect(
      restored.root.children.last.children.single.children.single.id,
      leaf.id,
    );
  });

  test('draft recovery retains descendant IDs for incremental saves', () async {
    final id = await repo.createPage();
    final root = Node(
      type: 'bulleted_list',
      children: [paragraphNode(text: 'Child')],
    );
    await repo.savePageNodes(id, [root]);
    final snapshot = await repo.loadPageSnapshot(id);
    await repo.saveDraft(
      'draft',
      id,
      snapshot.version,
      snapshot.document.root.children,
    );
    final restored = repo.documentFromDraft((await repo.getDrafts(id)).single);
    await auditWrites();
    await repo.savePageNodes(id, restored.root.children);
    expect(await writes(), isEmpty);
  });

  test('foreign and duplicate IDs are rejected without stealing or changing blocks', () async {
    final id = await repo.createPage();
    final other = await repo.createPage();
    final foreign = (await repo.loadPageDocument(other)).root.children.single;
    final before = await db.getAllBlocks();
    await expectLater(repo.savePageNodes(id, [foreign]), throwsArgumentError);
    final node = paragraphNode(text: 'Duplicate');
    await expectLater(
      repo.savePageNodes(id, [node, node]),
      throwsArgumentError,
    );
    expect(await db.getAllBlocks(), before);
  });

  test(
    'mixed delete, update and insert roll back together on failure',
    () async {
      final id = await repo.createPage();
      await repo.savePageNodes(id, [
        paragraphNode(text: 'Keep'),
        paragraphNode(text: 'Delete'),
      ]);
      final before = await db.getBlocksForPage(id);
      final nodes = (await repo.loadPageDocument(id)).root.children.toList();
      nodes.first.updateAttributes({
        'delta': (Delta()..insert('Changed')).toJson(),
      });
      await db.customStatement(
        '''CREATE TRIGGER reject_block_update BEFORE UPDATE ON blocks
      BEGIN SELECT RAISE(ABORT, 'Injected failure'); END''',
      );
      await expectLater(
        repo.savePageNodes(id, [nodes.first, paragraphNode(text: 'Insert')]),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.getBlocksForPage(id), before);
    },
  );

  test('separately trashed blocks are preserved and cannot be resurrected by a stale ID', () async {
    final id = await repo.createPage();
    final node = (await repo.loadPageDocument(id)).root.children.single;
    await (db.update(db.blocks)..where((t) => t.id.equals(node.id))).write(
      BlocksCompanion(trashedAt: drift.Value(DateTime(2020))),
    );
    await repo.savePageNodes(id, [paragraphNode(text: 'New')]);
    expect(
      (await db.getAllBlocks()).firstWhere((b) => b.id == node.id).trashedAt,
      isNotNull,
    );
    await expectLater(repo.savePageNodes(id, [node]), throwsArgumentError);
  });

  for (final archived in [true, false]) {
    test(
      'schema 7 migration expands legacy nested JSON (trashed: $archived)',
      () async {
        await db.close();
        final directory = await Directory.systemTemp.createTemp(
          'notes_here_blocks_',
        );
        addTearDown(() async {
          await db.close();
          if (await directory.exists()) {
            try {
              await directory.delete(recursive: true);
            } catch (_) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              if (await directory.exists()) {
                await directory.delete(recursive: true);
              }
            }
          }
        });
        final file = File('${directory.path}/notes.sqlite');
        db = AppDatabase(NativeDatabase(file));
        repo = NotesRepository(db);
        final id = await repo.createPage();
        final root = Node(
          type: 'bulleted_list',
          children: [
            Node(
              type: 'quote',
              children: [paragraphNode(text: 'Deep')],
            ),
          ],
        );
        await db.deletePageBlocks(id);
        await db.insertBlocksBatch([
          BlocksCompanion.insert(
            id: root.id,
            pageId: id,
            type: root.type,
            content: jsonEncode(root.toJson()),
            orderKey: 'a7',
          ),
        ]);
        if (archived) await repo.trashPage(id);
        for (final index in [
          'pages_database_order',
          'pages_parent_order',
          'blocks_page_order',
          'database_columns_order',
        ]) {
          await db.customStatement('DROP INDEX $index');
        }
        await db.customStatement('ALTER TABLE pages DROP COLUMN title_folded');
        await db.customStatement(
          'ALTER TABLE pages DROP COLUMN properties_folded',
        );
        await db.customStatement('PRAGMA user_version = 7');
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        repo = NotesRepository(db);
        final migrated = (await db.getAllBlocks())
            .where((b) => b.pageId == id)
            .toList();
        expect(migrated, hasLength(3));
        expect(migrated.every((b) => b.trashedAt != null), archived);
        expect(migrated.firstWhere((b) => b.id == root.id).orderKey, 'a7');
        if (archived) await repo.restorePage(id);
        final document = await repo.loadPageDocument(id);
        expect(document.root.children.single.id, root.id);
        expect(
          document.root.children.single.children.single.children.single.delta!
              .toPlainText(),
          'Deep',
        );
        final before = await db.getBlocksForPage(id);
        await repo.savePageNodes(id, document.root.children);
        expect(await db.getBlocksForPage(id), before);
      },
    );
  }

  test('flat workspace backups retain nested IDs and sibling keys', () async {
    final id = await repo.createPage();
    await repo.savePageNodes(id, [
      Node(
        type: 'bulleted_list',
        children: [
          paragraphNode(text: 'A'),
          paragraphNode(text: 'B'),
        ],
      ),
    ]);
    final before = await db.getBlocksForPage(id);
    final service = ExportImportService(repository: repo);
    final backup = await service.exportWorkspaceJson();
    await service.restoreWorkspaceJson(backup, wipeExisting: true);
    expect(await db.getBlocksForPage(id), before);
    await auditWrites();
    await repo.savePageNodes(
      id,
      (await repo.loadPageDocument(id)).root.children,
    );
    expect(await writes(), isEmpty);
  });

  test(
    'legacy workspace import is normalized inside the restore transaction',
    () async {
      final id = await repo.createPage();
      final root = Node(
        type: 'bulleted_list',
        children: [paragraphNode(text: 'Child')],
      );
      final service = ExportImportService(repository: repo);
      final backup = jsonDecode(
        await service.exportWorkspaceJson(),
      ) as Map<String, dynamic>;
      final legacy = (backup['blocks'] as List).single as Map;
      legacy['id'] = root.id;
      legacy['type'] = root.type;
      legacy['content'] = jsonEncode(root.toJson());
      await service.restoreWorkspaceJson(
        jsonEncode(backup),
        wipeExisting: true,
      );
      expect(await db.getBlocksForPage(id), hasLength(2));
      expect(
        (await repo.loadPageDocument(id))
            .root
            .children
            .single
            .children
            .single
            .delta!
            .toPlainText(),
        'Child',
      );
    },
  );
}
