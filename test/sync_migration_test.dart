import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/sync/sync_outbox.dart';
import 'package:notes_here/sync/sync_store.dart';

void main() {
  test('schema 10 upgrade retains pending operation identities and reinstalls version-aware triggers', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final raw = sqlite3.openInMemory();
    var db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    try {
      await SyncOutbox(db).enable();
      await db.upsertPage(
        PagesCompanion.insert(
          id: 'before',
          title: const Value('Before upgrade'),
        ),
      );
      final operation = (await SyncOutbox(db).pending()).single.operationId;
      await db.close();
      for (final trigger in raw.select(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'notes_sync_%'",
      )) {
        raw.execute('DROP TRIGGER ${trigger['name']}');
      }
      // Reconstruct the previously shipped v10 sync schema in an in-memory DB.
      raw.execute('ALTER TABLE notes_sync_outbox DROP COLUMN base_seq');
      raw.execute('ALTER TABLE notes_sync_outbox DROP COLUMN seen_seq');
      raw.execute('ALTER TABLE notes_sync_state DROP COLUMN cursor');
      raw.execute('ALTER TABLE notes_sync_state DROP COLUMN device_id');
      raw.execute('DROP TABLE notes_sync_shadow');
      raw.execute('DROP TABLE notes_sync_conflicts');
      raw.execute('DROP TABLE notes_sync_recovery');
      raw.execute('PRAGMA user_version=10');
      db = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      final pending = await SyncOutbox(db).pending();
      expect(pending.single.operationId, operation);
      expect(pending.single.baseSeq, 0);
      expect(pending.single.seenSeq, 0);
      expect((await SyncStore(db).deviceId).length, 32);
      await db.upsertPage(
        PagesCompanion.insert(id: 'after', title: const Value('After upgrade')),
      );
      expect(await SyncOutbox(db).pending(), hasLength(2));
      expect(await SyncStore(db).cursor, 0);
    } finally {
      await db.close();
      raw.close();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    }
  });
}
