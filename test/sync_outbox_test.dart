import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/sync/sync_outbox.dart';

void main() {
  late AppDatabase db;
  late SyncOutbox outbox;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = SyncOutbox(db);
  });
  tearDown(() => db.close());

  Future<void> page(String title) =>
      db.upsertPage(PagesCompanion.insert(id: 'page', title: Value(title)));

  test(
    'guest writes stay local; enabling captures existing rows only once',
    () async {
      await page('Offline');
      expect(await outbox.pending(), isEmpty);
      await outbox.enable();
      await outbox.enable();
      final batch = await outbox.pending();
      expect(batch, hasLength(1));
      expect(jsonDecode(batch.single.payload)['title'], 'Offline');
      expect(batch.single.entityType, 'pages');
    },
  );

  test('data and queued operations roll back together', () async {
    await outbox.enable();
    await expectLater(
      db.transaction(() async {
        await page('Must roll back');
        throw StateError('abort');
      }),
      throwsStateError,
    );
    expect(await db.getPageById('page'), isNull);
    expect(await outbox.pending(), isEmpty);
  });

  test(
    'acknowledging an old batch preserves newer edits; retries keep IDs',
    () async {
      await outbox.enable();
      await page('First');
      final first = (await outbox.pending()).single;
      expect((await outbox.pending()).single.operationId, first.operationId);
      await page('Second');
      await outbox.acknowledge([first.operationId]);
      final second = (await outbox.pending()).single;
      expect(jsonDecode(second.payload)['title'], 'Second');
      expect(second.operationId, isNot(first.operationId));
      await outbox.acknowledge([first.operationId]);
      expect(await outbox.pending(), hasLength(1));
    },
  );

  test(
    'hard deletion is durable and no-op updates do not produce events',
    () async {
      await outbox.enable();
      await page('Keep');
      await outbox.acknowledge(
        (await outbox.pending()).map((e) => e.operationId),
      );
      await page('Keep');
      expect(await outbox.pending(), isEmpty);
      await (db.delete(db.pages)..where((t) => t.id.equals('page'))).go();
      final deletion = (await outbox.pending()).single;
      expect(deletion.action, 'DELETE');
      expect(jsonDecode(deletion.payload)['id'], 'page');
    },
  );

  test(
    'drafts and local search maintenance never enter the upload queue',
    () async {
      await outbox.enable();
      await page('Title');
      await outbox.acknowledge(
        (await outbox.pending()).map((e) => e.operationId),
      );
      await db
          .into(db.editorDrafts)
          .insert(
            EditorDraftsCompanion.insert(
              id: 'draft',
              pageId: 'page',
              baseVersion: 'version',
              content: '[]',
              updatedAt: DateTime.now(),
            ),
          );
      await db.refreshRowSearchData();
      expect(await outbox.pending(), isEmpty);
    },
  );

  test('account database names are stable and reject path injection', () {
    const id = 'AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB';
    expect(
      AppDatabase.accountDatabaseName(id),
      AppDatabase.accountDatabaseName(id.toLowerCase()),
    );
    expect(AppDatabase.accountDatabaseName(id), isNot('notes_here_db'));
    expect(
      () => AppDatabase.accountDatabaseName('../guest'),
      throwsArgumentError,
    );
  });
}
