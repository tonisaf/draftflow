import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/services/export_import_service.dart';
import 'package:notes_here/sync/sync_engine.dart';
import 'package:notes_here/sync/sync_outbox.dart';
import 'package:notes_here/sync/sync_store.dart';
import 'package:notes_here/sync/sync_types.dart';

import 'support/sync_test_server.dart';

void main() {
  late AppDatabase a, b;
  late NotesRepository ra, rb;
  late SyncStore sa, sb;
  late NotesSyncEngine ea, eb;
  late SyncTestServer server;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    ra = NotesRepository(a);
    rb = NotesRepository(b);
    sa = SyncStore(a);
    sb = SyncStore(b);
    await SyncOutbox(a).enable();
    await SyncOutbox(b).enable();
    server = SyncTestServer();
    ea = NotesSyncEngine(
      store: sa,
      transport: MemoryNotesTransport(server, pageSize: 1),
    );
    eb = NotesSyncEngine(
      store: sb,
      transport: MemoryNotesTransport(server, pageSize: 1),
    );
  });
  tearDown(() async {
    await ea.close();
    await eb.close();
    await a.close();
    await b.close();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });
  Future<String> sharedPage() async {
    final id = await ra.createPage(title: 'Shared');
    await ea.sync();
    await eb.sync();
    expect(ea.phase, NotesSyncPhase.synced);
    expect(eb.phase, NotesSyncPhase.synced);
    return id;
  }

  test('two clients converge for pages, blocks, title edits, trash, restore and permanent deletion without echoes', () async {
    final id = await sharedPage();
    expect((await rb.getPage(id))!.title, 'Shared');
    expect(await b.getPageBlocksSnapshot(id), isNotNull);
    expect(await sb.pendingCount, 0);
    await rb.updatePageTitle(id, 'Edited on B');
    await eb.sync();
    await ea.sync();
    expect((await ra.getPage(id))!.title, 'Edited on B');
    await ra.trashPage(id);
    await ea.sync();
    await eb.sync();
    expect((await rb.getPage(id))!.trashedAt, isNotNull);
    await a.restorePage(id);
    await ea.sync();
    await eb.sync();
    expect((await rb.getPage(id))!.trashedAt, isNull);
    await a.permanentlyDeletePage(id);
    await ea.sync();
    await eb.sync();
    expect(await rb.getPage(id), isNull);
    expect(await b.getAllBlocks(), isEmpty);
    expect(await sb.pendingCount, 0);
    expect(await sa.pendingCount, 0);
  });
  test(
    'concurrent edits preserve both versions until explicit local resolution',
    () async {
      final id = await sharedPage();
      await ra.updatePageTitle(id, 'A version');
      await rb.updatePageTitle(id, 'B version');
      await ea.sync();
      await eb.sync();
      expect(eb.phase, NotesSyncPhase.conflict);
      expect((await rb.getPage(id))!.title, 'B version');
      final conflict = (await sb.conflicts()).single;
      expect(conflict.remote['title'], 'A version');
      expect(conflict.local!['title'], 'B version');
      await sb.resolve(conflict, useLocal: true);
      await eb.sync();
      await ea.sync();
      expect((await ra.getPage(id))!.title, 'B version');
      expect(ea.phase, NotesSyncPhase.synced);
      expect(eb.phase, NotesSyncPhase.synced);
      expect(await sb.lastRecoveryBackup(), isNotNull);
    },
  );
  test('accepting cloud keeps a restorable local backup', () async {
    final id = await sharedPage();
    await ra.updatePageTitle(id, 'Cloud');
    await rb.updatePageTitle(id, 'Local copy');
    await ea.sync();
    await eb.sync();
    await sb.resolve((await sb.conflicts()).single, useLocal: false);
    expect((await rb.getPage(id))!.title, 'Cloud');
    final backup = jsonDecode((await sb.lastRecoveryBackup())!) as Map;
    expect((backup['pages'] as List).single['title'], 'Local copy');
    expect(backup['format'], 'notes_here_workspace_backup');
    final restoredDb = AppDatabase(NativeDatabase.memory());
    try {
      final repo = NotesRepository(restoredDb);
      await ExportImportService(repository: repo)
          .restoreWorkspaceJson(jsonEncode(backup));
      expect((await repo.getPage(id))!.title, 'Local copy');
    } finally {
      await restoredDb.close();
    }
    await eb.sync();
    expect(await sb.pendingCount, 0);
  });
  test('lost upload response retries through journal without duplicating operations', () async {
    final id = await sharedPage();
    final before = server.log.length;
    await ra.updatePageTitle(id, 'Lost acknowledgement');
    server.loseResponse = true;
    await ea.sync();
    expect(ea.phase, NotesSyncPhase.offline);
    expect(await sa.pendingCount, 1);
    await ea.sync();
    expect(ea.phase, NotesSyncPhase.synced);
    expect(await sa.pendingCount, 0);
    expect(server.log.length, before + 1);
    await eb.sync();
    expect((await rb.getPage(id))!.title, 'Lost acknowledgement');
  });
  test('an edit made during upload survives the old acknowledgement and is uploaded next', () async {
    final id = await sharedPage();
    await ra.updatePageTitle(id, 'First');
    server.beforePush = () async {
      server.beforePush = null;
      await ra.updatePageTitle(id, 'Newer');
    };
    await ea.sync();
    await eb.sync();
    expect((await ra.getPage(id))!.title, 'Newer');
    expect((await rb.getPage(id))!.title, 'Newer');
    expect(await sa.pendingCount, 0);
  });
  test(
    'parent deletion never discards a pending edit to a nested descendant',
    () async {
      final root = await ra.createPage(title: 'Root');
      final child = await ra.createPage(title: 'Child', parentId: root);
      final leaf = await ra.createPage(title: 'Leaf', parentId: child);
      await ea.sync();
      await eb.sync();
      await rb.updatePageTitle(leaf, 'Unsynced leaf');
      await a.permanentlyDeletePage(root);
      await ea.sync();
      await eb.sync();
      expect(eb.phase, NotesSyncPhase.conflict);
      expect((await rb.getPage(leaf))!.title, 'Unsynced leaf');
      final rootConflict = (await sb.conflicts()).firstWhere(
        (c) => c.entityId == root,
      );
      await sb.resolve(rootConflict, useLocal: false);
      expect(await rb.getPage(root), isNull);
      expect(await rb.getPage(leaf), isNull);
      expect(await sb.pendingCount, 0);
      final backup = jsonDecode((await sb.lastRecoveryBackup())!) as Map;
      expect(
        (backup['pages'] as List).any((p) => p['title'] == 'Unsynced leaf'),
        isTrue,
      );
    },
  );
  test(
    'malformed incoming batch rolls back rows, cursor and echo suppression',
    () async {
      final id = await ra.createPage(title: 'Page');
      await ea.sync();
      final first = server.log.first;
      final malformed = RemoteChange(
        seq: 999,
        operationId: 'bad',
        deviceId: 'remote',
        entityType: 'pages',
        entityId: 'bad',
        action: 'UPSERT',
        payload: {'id': 'bad'},
      );
      await expectLater(sb.receive([first, malformed]), throwsFormatException);
      expect(await sb.cursor, 0);
      expect(await rb.getPage(id), isNull);
      await rb.createPage(title: 'Capture still enabled');
      expect(await sb.pendingCount, greaterThan(0));
    },
  );
  test(
    'stale conflict choice is refused after another remote version',
    () async {
      final id = await sharedPage();
      await ra.updatePageTitle(id, 'Cloud 1');
      await rb.updatePageTitle(id, 'Local');
      await ea.sync();
      await eb.sync();
      final reviewed = (await sb.conflicts()).single;
      await ra.updatePageTitle(id, 'Cloud 2');
      await ea.sync();
      await eb.sync();
      await expectLater(
        sb.resolve(reviewed, useLocal: true),
        throwsA(isA<SyncFailure>()),
      );
      expect((await rb.getPage(id))!.title, 'Local');
    },
  );
  test('local changes survive an offline cycle', () async {
    server.offline = true;
    await ra.createPage(title: 'Offline');
    await ea.sync();
    expect(ea.phase, NotesSyncPhase.offline);
    expect(await sa.pendingCount, greaterThan(0));
    server.offline = false;
    await ea.sync();
    await eb.sync();
    expect((await rb.db.getAllPages()).single.title, 'Offline');
  });
  test('databases, columns, row properties and deletion converge with foreign keys enabled', () async {
    await a.customStatement('PRAGMA foreign_keys=ON');
    await b.customStatement('PRAGMA foreign_keys=ON');
    final parent = await ra.createPage(title: 'Container');
    final database = await ra.createDatabase(
      title: 'Tasks',
      parentPageId: parent,
    );
    final rowId = await ra.createDatabaseRow(
      database,
      title: 'Row',
      properties: {'tag': 'Value'},
    );
    await ea.sync();
    await eb.sync();
    expect(ea.phase, NotesSyncPhase.synced);
    expect(eb.phase, NotesSyncPhase.synced);
    expect((await b.getAllDatabases()).single.title, 'Tasks');
    expect(await b.getAllDatabaseColumns(), isNotEmpty);
    expect((await rb.getPage(rowId))!.properties, contains('Value'));
    await a.deleteDatabasePermanently(database);
    await ea.sync();
    await eb.sync();
    expect(await b.getAllDatabases(), isEmpty);
    expect(await b.getAllDatabaseColumns(), isEmpty);
    expect(await rb.getPage(rowId), isNull);
    expect(await rb.getPage(parent), isNotNull);
  });
  test(
    'a newer local edit invalidates a previously reviewed conflict choice',
    () async {
      final id = await sharedPage();
      await ra.updatePageTitle(id, 'Cloud');
      await rb.updatePageTitle(id, 'Local 1');
      await ea.sync();
      await eb.sync();
      final reviewed = (await sb.conflicts()).single;
      await rb.updatePageTitle(id, 'Local 2');
      await expectLater(
        sb.resolve(reviewed, useLocal: false),
        throwsA(isA<SyncFailure>()),
      );
      expect((await rb.getPage(id))!.title, 'Local 2');
      final fresh = (await sb.conflicts()).single;
      expect(fresh.local!['title'], 'Local 2');
      await sb.resolve(fresh, useLocal: false);
      expect((await rb.getPage(id))!.title, 'Cloud');
    },
  );
  test(
    'stopped engine never applies an in-flight response to its old workspace',
    () async {
      await ra.createPage(title: 'Remote');
      await ea.sync();
      final transport = BlockedPullTransport();
      final engine = NotesSyncEngine(store: sb, transport: transport);
      final running = engine.sync();
      await transport.started.future;
      final stopped = engine.close();
      transport.response.complete(server.log.toList());
      await running;
      await stopped;
      expect(await b.getAllPages(), isEmpty);
      expect(await sb.cursor, 0);
    },
  );
}

class BlockedPullTransport implements NotesSyncTransport {
  final started = Completer<void>();
  final response = Completer<List<RemoteChange>>();
  @override
  Future<List<RemoteChange>> pull(int after) {
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  @override
  Future<void> push(String device, List<PendingChange> changes) async =>
      throw StateError('Unexpected upload');
}
