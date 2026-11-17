import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/app_database.dart';

/// Durable, at-least-once upload record. Reuse operationId on every retry.
class PendingChange {
  const PendingChange(
    this.operationId,
    this.entityType,
    this.entityId,
    this.action,
    this.payload, {
    this.baseSeq = 0,
    this.seenSeq = 0,
  });
  final String operationId;
  final String entityType;
  final String entityId;
  final String action;
  final String payload;
  final int baseSeq;
  final int seenSeq;

  Map<String, Object?> toJson() => {
    'operation_id': operationId,
    'entity_type': entityType,
    'entity_id': entityId,
    'action': action,
    'payload': jsonDecode(payload),
    'base_seq': baseSeq,
    'seen_seq': seenSeq,
  };
}

/// Storage only: no network or credentials. Every method is scoped to one DB.
class SyncOutbox {
  SyncOutbox(this.db);
  final AppDatabase db;

  /// Deliberate opt-in. Existing rows are captured once in the same transaction
  /// that enables triggers. Guest databases never start uploading implicitly.
  Future<void> enable() => db.transaction(() async {
    final state = await db
        .customSelect('SELECT enabled FROM notes_sync_state WHERE id = 1')
        .getSingle();
    if (state.read<int>('enabled') == 1) return;
    await _installSyncTriggers(db);
    for (final entry in syncColumns.entries) {
      final payload = jsonRow(entry.value, '');
      await db.customStatement('''
        INSERT INTO notes_sync_outbox
          (operation_id, entity_type, entity_id, action, payload)
        SELECT lower(hex(randomblob(16))), '${entry.key}', id, 'UPSERT',
          $payload FROM ${entry.key}
      ''');
    }
    await db.customStatement(
      'UPDATE notes_sync_state SET enabled = 1 WHERE id = 1',
    );
  });

  Future<List<PendingChange>> pending({int limit = 100}) async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    final rows = await db
        .customSelect(
          'SELECT * FROM notes_sync_outbox ORDER BY seq LIMIT ?',
          variables: [Variable.withInt(limit)],
        )
        .get();
    return [
      for (final r in rows)
        PendingChange(
          r.read<String>('operation_id'),
          r.read<String>('entity_type'),
          r.read<String>('entity_id'),
          r.read<String>('action'),
          r.read<String>('payload'),
          baseSeq: r.read<int>('base_seq'),
          seenSeq: r.read<int>('seen_seq'),
        ),
    ];
  }

  /// Ack only operations confirmed by the server, never every edit for an ID.
  Future<void> acknowledge(Iterable<String> operationIds) =>
      db.transaction(() async {
        for (final id in operationIds) {
          await db.customStatement(
            'DELETE FROM notes_sync_outbox WHERE operation_id = ?',
            [id],
          );
        }
      });
}

/// Explicit wire fields: local search indexes and editor drafts stay local.
const syncColumns = <String, List<String>>{
  'pages': [
    'id',
    'title',
    'parent_id',
    'icon',
    'cover',
    'order_key',
    'database_id',
    'properties',
    'created_at',
    'trashed_at',
    'trash_batch_id',
  ],
  'blocks': [
    'id',
    'page_id',
    'parent_id',
    'type',
    'content',
    'order_key',
    'trashed_at',
    'trash_batch_id',
  ],
  'databases': [
    'id',
    'title',
    'icon',
    'parent_page_id',
    'created_at',
    'trashed_at',
    'trash_batch_id',
  ],
  'database_columns': [
    'id',
    'database_id',
    'name',
    'type',
    'options',
    'width',
    'order_key',
    'created_at',
  ],
};

String jsonRow(List<String> columns, String prefix) =>
    'json_object(${columns.map((c) => "'$c', $prefix$c").join(', ')})';

/// Called for both fresh installs and upgrades; no generated Drift models needed.
Future<void> installSyncStorage(AppDatabase db) async {
  await db.customStatement('''CREATE TABLE IF NOT EXISTS notes_sync_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    enabled INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1))
  )''');
  await db.customStatement(
    'INSERT OR IGNORE INTO notes_sync_state (id) VALUES (1)',
  );
  await db.customStatement('''CREATE TABLE IF NOT EXISTS notes_sync_outbox (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT NOT NULL UNIQUE,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('UPSERT', 'DELETE')),
    payload TEXT NOT NULL
  )''');
  final stateColumns = await db
      .customSelect('PRAGMA table_info(notes_sync_state)')
      .get();
  final stateNames = stateColumns.map((r) => r.read<String>('name')).toSet();
  if (!stateNames.contains('cursor')) {
    await db.customStatement(
      'ALTER TABLE notes_sync_state ADD COLUMN cursor INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (!stateNames.contains('device_id')) {
    await db.customStatement(
      "ALTER TABLE notes_sync_state ADD COLUMN device_id TEXT NOT NULL DEFAULT ''",
    );
  }
  await db.customStatement(
    "UPDATE notes_sync_state SET device_id = lower(hex(randomblob(16))) WHERE device_id = ''",
  );
  final queueColumns = await db
      .customSelect('PRAGMA table_info(notes_sync_outbox)')
      .get();
  final queueNames = queueColumns.map((r) => r.read<String>('name')).toSet();
  for (final column in ['base_seq', 'seen_seq']) {
    if (!queueNames.contains(column)) {
      await db.customStatement(
        'ALTER TABLE notes_sync_outbox ADD COLUMN $column INTEGER NOT NULL DEFAULT 0',
      );
    }
  }
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS notes_sync_outbox_entity ON notes_sync_outbox(entity_type, entity_id, seq)',
  );
  await db.customStatement('''CREATE TABLE IF NOT EXISTS notes_sync_shadow (
    entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, seq INTEGER NOT NULL,
    action TEXT NOT NULL, payload TEXT NOT NULL,
    PRIMARY KEY (entity_type, entity_id)
  )''');
  await db.customStatement('''CREATE TABLE IF NOT EXISTS notes_sync_conflicts (
    entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
    remote_seq INTEGER NOT NULL, remote_action TEXT NOT NULL,
    remote_payload TEXT NOT NULL, local_payload TEXT,
    PRIMARY KEY (entity_type, entity_id)
  )''');
  await db.customStatement('''CREATE TABLE IF NOT EXISTS notes_sync_recovery (
    id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL,
    payload TEXT NOT NULL
  )''');
  final state = await db
      .customSelect('SELECT enabled FROM notes_sync_state WHERE id = 1')
      .getSingle();
  if (state.read<int>('enabled') == 1) await _installSyncTriggers(db);
}

Future<void> _installSyncTriggers(AppDatabase db) async {
  for (final entry in syncColumns.entries) {
    final table = entry.key;
    for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
      final ref = action == 'DELETE' ? 'OLD.' : 'NEW.';
      final payload = jsonRow(entry.value, ref);
      final previous = jsonRow(entry.value, 'OLD.');
      final changed = action == 'UPDATE'
          ? ' AND $previous IS NOT $payload'
          : '';
      final operation = action == 'DELETE' ? 'DELETE' : 'UPSERT';
      await db.customStatement(
        'DROP TRIGGER IF EXISTS notes_sync_${table}_${action.toLowerCase()}',
      );
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS notes_sync_${table}_${action.toLowerCase()}
        AFTER $action ON $table
        WHEN (SELECT enabled FROM notes_sync_state WHERE id = 1) = 1 $changed
        BEGIN
          INSERT INTO notes_sync_outbox
            (operation_id, entity_type, entity_id, action, payload, base_seq, seen_seq)
          VALUES (lower(hex(randomblob(16))), '$table', ${ref}id, '$operation', $payload,
            COALESCE((SELECT seq FROM notes_sync_shadow WHERE entity_type = '$table' AND entity_id = ${ref}id), 0),
            (SELECT cursor FROM notes_sync_state WHERE id = 1));
        END''',
      );
    }
  }
}
