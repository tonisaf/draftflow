import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/auto_save_service.dart';

void main() {
  test(
    'draft survives a database reopen with nested blocks and formatting',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'notes_here_drafts_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/notes.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      var repo = NotesRepository(db);
      final id = await repo.createPage();
      final snapshot = await repo.loadPageSnapshot(id);
      final nodes = [
        paragraphNode(
          delta: Delta()
            ..insert(
              'Link',
              attributes: {'href': 'page://target', 'bold': true},
            ),
        ),
        Node(
          type: 'code',
          attributes: {
            'language': 'dart',
            'delta': (Delta()..insert('void main() {}')).toJson(),
          },
          children: [paragraphNode(text: 'Nested')],
        ),
      ];
      await repo.saveDraft('draft', id, snapshot.version, nodes);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repo = NotesRepository(db);
      final draft = (await repo.getDrafts(id)).single;
      final restored = repo.documentFromDraft(draft);
      expect(
        restored.root.children.map((n) => n.toJson()).toList(),
        nodes.map((n) => n.toJson()).toList(),
      );
      expect(restored.root.children.first.id, nodes.first.id);
      expect(draft.baseVersion, snapshot.version);
      await db.close();
    },
  );

  test('schema 5 upgrades without losing pages', () async {
    final directory = await Directory.systemTemp.createTemp(
      'notes_here_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/notes.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final id = await NotesRepository(db).createPage(title: 'Existing note');
    await db.customStatement('DROP TABLE editor_drafts');
    for (final table in ['pages', 'blocks', 'databases']) {
      await db.customStatement('ALTER TABLE $table DROP COLUMN trash_batch_id');
    }
    for (final index in [
      'pages_database_order',
      'pages_parent_order',
      'blocks_page_order',
      'database_columns_order',
    ]) {
      await db.customStatement('DROP INDEX $index');
    }
    await db.customStatement('ALTER TABLE pages DROP COLUMN title_folded');
    await db.customStatement('ALTER TABLE pages DROP COLUMN properties_folded');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    final repo = NotesRepository(db);
    expect((await repo.getPage(id))!.title, 'Existing note');
    await repo.saveDraft('draft', id, 'base', [paragraphNode(text: 'Draft')]);
    expect((await repo.getDrafts(id)).length, 1);
    await db.close();
  });

  for (final useLocal in [true, false]) {
    test(
      'resolution (${useLocal ? 'local' : 'saved'}) refuses a stale reviewed version',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = NotesRepository(db);
        final id = await repo.createPage();
        final base = await repo.loadPageSnapshot(id);
        await repo.saveDraft('recovery', id, base.version, [
          paragraphNode(text: 'Local'),
        ]);
        final recovered = (await repo.getDrafts(id)).single;
        final editor = EditorState(document: repo.documentFromDraft(recovered));
        final service = AutoSaveService(
          repository: repo,
          pageId: id,
          editorState: editor,
          initialVersion: recovered.baseVersion,
          recoveredDraft: recovered,
        );
        addTearDown(service.dispose);
        await repo.savePageNodes(id, [paragraphNode(text: 'External')]);
        final reviewed = await repo.loadPageSnapshot(id);
        await repo.savePageNodes(id, [paragraphNode(text: 'Newer external')]);
        if (useLocal) {
          expect(await service.useLocalVersion(reviewed.version), isFalse);
        } else {
          await expectLater(
            service.useSavedVersion(reviewed.version),
            throwsA(isA<DocumentConflictException>()),
          );
        }
        expect((await repo.getDrafts(id)).isNotEmpty, isTrue);
        final latest = await repo.loadPageSnapshot(id);
        if (useLocal) {
          expect(await service.useLocalVersion(latest.version), isTrue);
        } else {
          await service.useSavedVersion(latest.version);
        }
        await service.forceSave(); // Must not recreate a resolved draft.
        expect(await repo.getDrafts(id), isEmpty);
        expect(
          (await repo.loadPageDocument(id)).root.children.single.delta!
              .toPlainText(),
          useLocal ? 'Local' : 'Newer external',
        );
      },
    );
  }

  test(
    'two editor sessions keep independent drafts and further conflict edits',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = NotesRepository(db);
      final id = await repo.createPage();
      final base = await repo.loadPageSnapshot(id);
      final editors = [
        EditorState(document: base.document),
        EditorState(document: (await repo.loadPageSnapshot(id)).document),
      ];
      final services = editors
          .map(
            (editor) => AutoSaveService(
              repository: repo,
              pageId: id,
              editorState: editor,
              initialVersion: base.version,
              debounceDuration: const Duration(days: 1),
            ),
          )
          .toList();
      addTearDown(() {
        for (final service in services) {
          service.dispose();
        }
      });
      await repo.savePageNodes(id, [paragraphNode(text: 'External')]);
      for (var i = 0; i < editors.length; i++) {
        await editors[i].apply(
          editors[i].transaction..insertText(
            editors[i].document.root.children.first,
            0,
            'Draft $i',
          ),
        );
        await services[i].forceSave();
      }
      await editors.first.apply(
        editors.first.transaction..insertText(
          editors.first.document.root.children.first,
          7,
          ' updated',
        ),
      );
      await services.first.forceSave();
      final drafts = await repo.getDrafts(id);
      expect(drafts.length, 2);
      expect(
        drafts.map(
          (d) => repo
              .documentFromDraft(d)
              .root
              .children
              .first
              .delta!
              .toPlainText(),
        ),
        contains('Draft 0 updated'),
      );
      await services.first.useSavedVersion(
        (await repo.loadPageSnapshot(id)).version,
      );
      expect((await repo.getDrafts(id)).single.id, services.last.draftId);
    },
  );
}
