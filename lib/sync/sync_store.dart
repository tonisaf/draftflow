import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/app_database.dart';
import '../data/model/database_query.dart';
import 'sync_outbox.dart';
import 'sync_types.dart';

class SyncConflict {
  const SyncConflict(
    this.entityType,
    this.entityId,
    this.remoteSeq,
    this.remoteAction,
    this.remote,
    this.local,
  );
  final String entityType, entityId, remoteAction;
  final int remoteSeq;
  final Map<String, dynamic> remote;
  final Map<String, dynamic>? local;
}

class SyncStore {
  SyncStore(this.db);
  final AppDatabase db;
  final changedPages = <String>{};
  Future<int> get cursor async =>
      (await db
              .customSelect('SELECT cursor FROM notes_sync_state WHERE id = 1')
              .getSingle())
          .read<int>('cursor');
  Future<String> get deviceId async =>
      (await db
              .customSelect(
                'SELECT device_id FROM notes_sync_state WHERE id = 1',
              )
              .getSingle())
          .read<String>('device_id');
  Future<int> get pendingCount async =>
      (await db
              .customSelect('SELECT count(*) AS n FROM notes_sync_outbox')
              .getSingle())
          .read<int>('n');
  Future<List<SyncConflict>> conflicts() async => [
    for (final r
        in await db
            .customSelect(
              'SELECT * FROM notes_sync_conflicts ORDER BY remote_seq',
            )
            .get())
      SyncConflict(
        r.read<String>('entity_type'),
        r.read<String>('entity_id'),
        r.read<int>('remote_seq'),
        r.read<String>('remote_action'),
        _decode(r.read<String>('remote_payload')),
        await row(r.read<String>('entity_type'), r.read<String>('entity_id')),
      ),
  ];
  static Map<String, dynamic> _decode(String text) =>
      Map<String, dynamic>.from(jsonDecode(text) as Map);
  Future<Map<String, dynamic>?> row(String type, String id) async {
    final columns = syncColumns[type];
    if (columns == null) throw const FormatException('Unknown entity type');
    final rows = await db
        .customSelect(
          'SELECT ${jsonRow(columns, '')} AS payload FROM $type WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return rows.isEmpty ? null : _decode(rows.single.read<String>('payload'));
  }

  Future<bool> _pending(String type, String id) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM notes_sync_outbox WHERE entity_type = ? AND entity_id = ? LIMIT 1',
                variables: [Variable.withString(type), Variable.withString(id)],
              )
              .get())
          .isNotEmpty;

  /// Conservative structural guard: parent/child edits are never discarded by
  /// applying a remote parent deletion or by inserting a child into a local deletion.
  Future<bool> _relatedPending(RemoteChange event) async {
    if (await _pending(event.entityType, event.entityId)) return true;
    for (final ref in references(event.entityType, event.payload)) {
      if (await _pending(ref.$1, ref.$2)) return true;
    }
    if (event.action != 'DELETE') return false;
    final queue = await db
        .customSelect(
          'SELECT entity_type, entity_id, payload FROM notes_sync_outbox ORDER BY seq',
        )
        .get();
    final queued = <(String, String), Map<String, dynamic>>{};
    for (final item in queue) {
      queued[(
        item.read<String>('entity_type'),
        item.read<String>('entity_id'),
      )] = _decode(
        item.read<String>('payload'),
      );
    }
    Future<bool> depends(String type, Map<String, dynamic> payload) async {
      final visited = <(String, String)>{};
      final refs = references(type, payload).toList();
      for (var i = 0; i < refs.length; i++) {
        final ref = refs[i];
        if (ref == (event.entityType, event.entityId)) return true;
        if (!visited.add(ref)) continue;
        final parent = queued[ref] ?? await row(ref.$1, ref.$2);
        if (parent != null) refs.addAll(references(ref.$1, parent));
      }
      return false;
    }

    for (final item in queued.entries) {
      if (await depends(item.key.$1, item.value)) return true;
    }
    for (final draft in await db.select(db.editorDrafts).get()) {
      if (event.entityType == 'pages' && draft.pageId == event.entityId) {
        return true;
      }
      final page = await row('pages', draft.pageId);
      if (page != null && await depends('pages', page)) return true;
    }
    return false;
  }

  static List<(String, String)> references(
    String type,
    Map<String, dynamic> payload,
  ) {
    final result = <(String, String)>[];
    void add(String field, String target) {
      final id = payload[field];
      if (id is String) result.add((target, id));
    }

    switch (type) {
      case 'pages':
        add('parent_id', 'pages');
        add('database_id', 'databases');
      case 'blocks':
        add('page_id', 'pages');
        add('parent_id', 'blocks');
      case 'databases':
        add('parent_page_id', 'pages');
      case 'database_columns':
        add('database_id', 'databases');
    }
    return result;
  }

  Future<T> withoutEcho<T>(Future<T> Function() action) =>
      db.transaction(() async {
        final state = await db
            .customSelect('SELECT enabled FROM notes_sync_state WHERE id = 1')
            .getSingle();
        await db.customStatement(
          'UPDATE notes_sync_state SET enabled = 0 WHERE id = 1',
        );
        try {
          return await action();
        } finally {
          await db.customStatement(
            'UPDATE notes_sync_state SET enabled = ? WHERE id = 1',
            [state.read<int>('enabled')],
          );
        }
      });

  /// Cursor, acknowledgement, row changes and conflict records commit together.
  Future<bool> receive(List<RemoteChange> events) => withoutEcho(() async {
    changedPages.clear();
    var after = await cursor;
    final device = await deviceId;
    var changed = false;
    for (final event in events) {
      if (event.seq <= after) {
        throw const FormatException('Unordered sync response');
      }
      final columns = syncColumns[event.entityType];
      if (columns == null ||
          event.payload['id'] != event.entityId ||
          !['UPSERT', 'DELETE'].contains(event.action) ||
          columns.any((c) => !event.payload.containsKey(c)) ||
          event.payload.keys.any((c) => !columns.contains(c))) {
        throw const FormatException('Invalid sync event');
      }
      final encoded = jsonEncode(event.payload);
      if (event.deviceId == device) {
        // Keep newer local edits. Rebase only this device's subsequent operations
        // after its accepted operation, never after another device's change.
        final accepted = await db
            .customSelect(
              'SELECT seq, base_seq FROM notes_sync_outbox WHERE operation_id = ?',
              variables: [Variable.withString(event.operationId)],
            )
            .get();
        if (accepted.isNotEmpty) {
          await db.customStatement(
            'UPDATE notes_sync_outbox SET base_seq = ? WHERE entity_type = ? AND entity_id = ? AND seq > ? AND base_seq = ?',
            [
              event.seq,
              event.entityType,
              event.entityId,
              accepted.single.read<int>('seq'),
              accepted.single.read<int>('base_seq'),
            ],
          );
          await SyncOutbox(db).acknowledge([event.operationId]);
        }
      } else {
        final local = await row(event.entityType, event.entityId);
        final conflict = await _relatedPending(event);
        final alreadyBlocked =
            (await db
                    .customSelect(
                      'SELECT 1 FROM notes_sync_conflicts WHERE entity_type = ? AND entity_id = ?',
                      variables: [
                        Variable.withString(event.entityType),
                        Variable.withString(event.entityId),
                      ],
                    )
                    .get())
                .isNotEmpty;
        if (conflict || alreadyBlocked) {
          await db.customStatement(
            'INSERT INTO notes_sync_conflicts (entity_type, entity_id, remote_seq, remote_action, remote_payload, local_payload) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(entity_type, entity_id) DO UPDATE SET remote_seq=excluded.remote_seq, remote_action=excluded.remote_action, remote_payload=excluded.remote_payload, local_payload=excluded.local_payload',
            [
              event.entityType,
              event.entityId,
              event.seq,
              event.action,
              encoded,
              local == null ? null : jsonEncode(local),
            ],
          );
        } else {
          if (event.entityType == 'blocks') {
            changedPages.add(event.payload['page_id'] as String);
          }
          if (event.action == 'DELETE' &&
              ['pages', 'databases'].contains(event.entityType)) {
            changedPages.addAll(
              (await _ownedEntities(
                event.entityType,
                event.entityId,
              )).where((e) => e.$1 == 'pages').map((e) => e.$2),
            );
          }
          await _apply(
            event.entityType,
            event.entityId,
            event.action,
            event.payload,
          );
          changed = true;
        }
      }
      await db.customStatement(
        'INSERT INTO notes_sync_shadow (entity_type, entity_id, seq, action, payload) VALUES (?, ?, ?, ?, ?) ON CONFLICT(entity_type, entity_id) DO UPDATE SET seq=excluded.seq, action=excluded.action, payload=excluded.payload',
        [event.entityType, event.entityId, event.seq, event.action, encoded],
      );
      after = event.seq;
    }
    await db.customStatement(
      'UPDATE notes_sync_state SET cursor = ? WHERE id = 1',
      [after],
    );
    if (changed) {
      db.markTablesUpdated({
        db.pages,
        db.blocks,
        db.databases,
        db.databaseColumns,
      });
    }
    return changed;
  });

  Future<void> _apply(
    String type,
    String id,
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (action == 'DELETE') {
      if (type == 'pages') {
        await db.permanentlyDeletePage(id);
      } else if (type == 'databases') {
        await db.deleteDatabasePermanently(id);
      } else if (type == 'blocks') {
        await db.customStatement(
          'WITH RECURSIVE subtree(id) AS (SELECT id FROM blocks WHERE id=? UNION SELECT b.id FROM blocks b JOIN subtree s ON b.parent_id=s.id) DELETE FROM blocks WHERE id IN (SELECT id FROM subtree)',
          [id],
        );
      } else {
        await db.customStatement('DELETE FROM $type WHERE id = ?', [id]);
      }
      return;
    }
    final columns = syncColumns[type]!;
    await db.customStatement(
      'INSERT INTO $type (${columns.join(',')}) VALUES (${List.filled(columns.length, '?').join(',')}) ON CONFLICT(id) DO UPDATE SET ${columns.where((c) => c != 'id').map((c) => '$c=excluded.$c').join(',')}',
      [for (final c in columns) payload[c]],
    );
    if (type == 'pages') {
      await db.customStatement(
        'UPDATE pages SET title_folded = ?, properties_folded = ? WHERE id = ?',
        [
          (payload['title'] as String).toLowerCase(),
          foldProperties(payload['properties'] as String?),
          id,
        ],
      );
    }
  }

  /// Only one queued operation per entity can be in flight. Dependencies are
  /// visited first, even if their local operation was appended later.
  Future<List<PendingChange>> uploadBatch() async {
    final first = await db
        .customSelect(
          'SELECT q.* FROM notes_sync_outbox q WHERE NOT EXISTS (SELECT 1 FROM notes_sync_outbox p WHERE p.entity_type=q.entity_type AND p.entity_id=q.entity_id AND p.seq<q.seq) ORDER BY q.seq LIMIT 100',
        )
        .get();
    final result = <PendingChange>[];
    final visited = <(String, String)>{};
    final visiting = <(String, String)>{};
    Future<void> visit(QueryRow r) async {
      final key = (r.read<String>('entity_type'), r.read<String>('entity_id'));
      if (visited.contains(key)) return;
      if (!visiting.add(key)) {
        throw const SyncFailure(
          'Изменения структуры требуют разрешения конфликта.',
        );
      }
      final payload = _decode(r.read<String>('payload'));
      if (r.read<String>('action') == 'UPSERT') {
        for (final ref in references(key.$1, payload)) {
          final dependency = await db
              .customSelect(
                'SELECT * FROM notes_sync_outbox WHERE entity_type = ? AND entity_id = ? ORDER BY seq LIMIT 1',
                variables: [
                  Variable.withString(ref.$1),
                  Variable.withString(ref.$2),
                ],
              )
              .get();
          if (dependency.isNotEmpty &&
              dependency.single.read<String>('action') == 'UPSERT') {
            await visit(dependency.single);
          }
        }
      }
      visiting.remove(key);
      visited.add(key);
      result.add(
        PendingChange(
          r.read<String>('operation_id'),
          key.$1,
          key.$2,
          r.read<String>('action'),
          r.read<String>('payload'),
          baseSeq: r.read<int>('base_seq'),
          seenSeq: r.read<int>('seen_seq'),
        ),
      );
    }

    for (final r in first) {
      await visit(r);
      if (result.length >= 100) break;
    }
    final bounded = <PendingChange>[];
    var bytes = 0;
    for (final change in result.take(100)) {
      final length = utf8.encode(jsonEncode(change.toJson())).length;
      if (length > 3 * 1024 * 1024) {
        throw const SyncFailure(
          'Изменение слишком велико для отправки. Разделите содержимое страницы на блоки.',
        );
      }
      if (bytes + length > 3 * 1024 * 1024) break;
      bytes += length;
      bounded.add(change);
    }
    return bounded;
  }

  Future<void> rejected(String type, String id) async {
    if (!syncColumns.containsKey(type)) {
      throw const FormatException('Invalid rejected entity');
    }
    final existing = await db
        .customSelect(
          'SELECT * FROM notes_sync_shadow WHERE entity_type = ? AND entity_id = ?',
          variables: [Variable.withString(type), Variable.withString(id)],
        )
        .get();
    final local = await row(type, id);
    if (existing.isEmpty && local == null) {
      throw const SyncFailure('Не удалось определить конфликтующую версию.');
    }
    final remote = existing.isEmpty
        ? local!
        : _decode(existing.single.read<String>('payload'));
    await db.customStatement(
      'INSERT OR REPLACE INTO notes_sync_conflicts (entity_type, entity_id, remote_seq, remote_action, remote_payload, local_payload) VALUES (?, ?, ?, ?, ?, ?)',
      [
        type,
        id,
        existing.isEmpty ? 0 : existing.single.read<int>('seq'),
        existing.isEmpty ? 'DELETE' : existing.single.read<String>('action'),
        jsonEncode(remote),
        local == null ? null : jsonEncode(local),
      ],
    );
  }

  Future<Set<(String, String)>> _ownedEntities(String type, String id) async {
    final payloads = <(String, String), Map<String, dynamic>>{};
    for (final table in syncColumns.keys) {
      for (final r
          in await db
              .customSelect(
                "SELECT ${jsonRow(syncColumns[table]!, '')} AS payload FROM $table",
              )
              .get()) {
        final p = _decode(r.read<String>('payload'));
        payloads[(table, p['id'] as String)] = p;
      }
    }
    for (final r
        in await db
            .customSelect(
              'SELECT entity_type,entity_id,payload FROM notes_sync_outbox',
            )
            .get()) {
      payloads[(r.read<String>('entity_type'), r.read<String>('entity_id'))] =
          _decode(r.read<String>('payload'));
    }
    final owned = <(String, String)>{(type, id)};
    var grew = true;
    while (grew) {
      grew = false;
      for (final e in payloads.entries) {
        if (!owned.contains(e.key) &&
            references(e.key.$1, e.value).any(owned.contains)) {
          owned.add(e.key);
          grew = true;
        }
      }
    }
    return owned;
  }

  Future<String?> lastRecoveryBackup() async {
    final rows = await db
        .customSelect(
          'SELECT payload FROM notes_sync_recovery ORDER BY id DESC LIMIT 1',
        )
        .get();
    if (rows.isEmpty) return null;
    final raw = _decode(rows.single.read<String>('payload'));
    String camel(String key) =>
        key.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase());
    final backup = <String, dynamic>{
      'format': 'notes_here_workspace_backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    for (final type in syncColumns.keys) {
      backup[type == 'database_columns' ? 'databaseColumns' : type] = [
        for (final row in raw[type] as List)
          {
            for (final c in syncColumns[type]!)
              camel(c): c.endsWith('_at') && row[c] is num
                  ? DateTime.fromMillisecondsSinceEpoch(
                      (row[c] as num).toInt() * 1000,
                      isUtc: true,
                    ).toIso8601String()
                  : row[c],
          },
      ];
    }
    backup['syncRecoveryDrafts'] = raw['editor_drafts'];
    backup['syncRecoveryOutbox'] = raw['outbox'];
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Resolution retains a complete local recovery snapshot before changing data.
  /// Call after the editor save barrier, with the version the user reviewed.
  Future<void> resolve(
    SyncConflict reviewed, {
    required bool useLocal,
  }) => withoutEcho(() async {
    final current = (await conflicts())
        .where(
          (c) =>
              c.entityType == reviewed.entityType &&
              c.entityId == reviewed.entityId,
        )
        .firstOrNull;
    if (current == null || current.remoteSeq != reviewed.remoteSeq) {
      throw const SyncFailure('Версия изменилась. Откройте сравнение заново.');
    }
    if (jsonEncode(current.local) != jsonEncode(reviewed.local)) {
      throw const SyncFailure(
        'Локальная версия изменилась. Откройте сравнение заново.',
      );
    }
    final recovery = <String, dynamic>{
      'format': 'notes_here_sync_recovery',
      'version': 1,
    };
    for (final table in [...syncColumns.keys, 'editor_drafts']) {
      recovery[table] = [
        for (final r in await db.customSelect('SELECT * FROM $table').get())
          r.data,
      ];
    }
    recovery['outbox'] = [
      for (final r
          in await db.customSelect('SELECT * FROM notes_sync_outbox').get())
        r.data,
    ];
    await db.customStatement(
      'INSERT INTO notes_sync_recovery (created_at, payload) VALUES (?, ?)',
      [DateTime.now().toUtc().toIso8601String(), jsonEncode(recovery)],
    );
    final type = current.entityType, id = current.entityId;
    final local = await row(type, id);
    await db.customStatement(
      'DELETE FROM notes_sync_outbox WHERE entity_type = ? AND entity_id = ?',
      [type, id],
    );
    if (useLocal) {
      await db.customStatement(
        'INSERT INTO notes_sync_outbox (operation_id, entity_type, entity_id, action, payload, base_seq, seen_seq) VALUES (lower(hex(randomblob(16))), ?, ?, ?, ?, ?, ?)',
        [
          type,
          id,
          local == null ? 'DELETE' : 'UPSERT',
          jsonEncode(local ?? current.remote),
          current.remoteSeq,
          await cursor,
        ],
      );
    } else {
      if (current.remoteAction == 'DELETE') {
        for (final owned in await _ownedEntities(type, id)) {
          await db.customStatement(
            'DELETE FROM notes_sync_outbox WHERE entity_type=? AND entity_id=?',
            [owned.$1, owned.$2],
          );
          await db.customStatement(
            'DELETE FROM notes_sync_conflicts WHERE entity_type=? AND entity_id=?',
            [owned.$1, owned.$2],
          );
        }
      }
      await _apply(type, id, current.remoteAction, current.remote);
    }
    await db.customStatement(
      'DELETE FROM notes_sync_conflicts WHERE entity_type = ? AND entity_id = ?',
      [type, id],
    );
    db.markTablesUpdated({
      db.pages,
      db.blocks,
      db.databases,
      db.databaseColumns,
    });
  });
}
