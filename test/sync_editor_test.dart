import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/account/account_controller.dart';
import 'package:notes_here/data/db/app_database.dart';
import 'package:notes_here/data/notes_repository.dart';
import 'package:notes_here/main.dart';
import 'package:notes_here/sync/account_sync_provider.dart';
import 'package:notes_here/sync/sync_engine.dart';
import 'package:notes_here/sync/sync_outbox.dart';
import 'package:notes_here/sync/sync_store.dart';

import 'support/fake_account_auth.dart';
import 'support/sync_test_server.dart';

class EditorSyncAuth extends FakeAccountAuth implements AccountSyncProvider {
  EditorSyncAuth(this.server);
  final SyncTestServer server;
  @override
  bool canSync(String userId) => identity?.id == userId;
  @override
  NotesSyncEngine createSync(
    NotesRepository repo,
    String userId,
    void Function() changed,
    Future<bool> Function(Future<bool> Function()) gate,
  ) => NotesSyncEngine(
    store: SyncStore(repo.db),
    transport: MemoryNotesTransport(server),
    onRemoteApplied: changed,
    applyRemote: gate,
    pollInterval: const Duration(hours: 1),
  );
}

void main() {
  for (final dirty in [false, true]) {
    testWidgets(
      'incoming block change updates open editor without losing typing (dirty: $dirty)',
      (tester) async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final a = AppDatabase(NativeDatabase.memory()),
            b = AppDatabase(NativeDatabase.memory());
        final guestDb = AppDatabase(NativeDatabase.memory());
        final ra = NotesRepository(a),
            rb = NotesRepository(b),
            guest = NotesRepository(guestDb);
        await SyncOutbox(a).enable();
        await SyncOutbox(b).enable();
        final server = SyncTestServer();
        final sender = NotesSyncEngine(
          store: SyncStore(a),
          transport: MemoryNotesTransport(server),
        );
        final id = await ra.createPage(title: 'Editor');
        await ra.savePageNodes(id, [
          paragraphNode(delta: Delta()..insert('Original')),
        ]);
        await sender.sync();
        final auth = EditorSyncAuth(server)
          ..identity = const NotesIdentity('account', 'a@example.com');
        final accounts = AccountController(
          guest: guest,
          auth: auth,
          openAccount: (_) async => rb,
        );
        await tester.pumpWidget(
          NotesApp(repository: guest, accountController: accounts),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        await accounts.signIn('a@example.com', 'password');
        // The save gate awaits a frame only once an editor is mounted.
        await accounts.syncEngine!.sync();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        var state = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState;
        expect(jsonEncode(state.document.toJson()), contains('Original'));
        if (dirty) {
          final transaction = state.transaction;
          transaction.insertText(
            state.document.root.children.first,
            0,
            'Local ',
          );
          await state.apply(transaction);
          expect(
            jsonEncode(state.document.toJson()),
            contains('Local Original'),
          );
        }
        final snapshot = await ra.loadPageSnapshot(id);
        snapshot.document.root.children.first.updateAttributes({
          'delta': (Delta()..insert('Remote text')).toJson(),
        });
        await ra.savePageNodes(id, snapshot.document.root.children);
        await sender.sync();
        final syncing = accounts.syncEngine!.sync();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        await syncing;
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        state = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState;
        if (dirty) {
          expect(
            jsonEncode(state.document.toJson()),
            contains('Local Original'),
          );
          expect(
            (await SyncStore(b).conflicts()).single.remote['content'],
            contains('Remote text'),
          );
          expect(
            (await rb.loadPageSnapshot(id)).document.toJson().toString(),
            contains('Local Original'),
          );
        } else {
          expect(jsonEncode(state.document.toJson()), contains('Remote text'));
          expect(await SyncStore(b).pendingCount, 0);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        await tester.runAsync(() => accounts.syncEngine!.close());
        accounts.dispose();
        await tester.runAsync(() => sender.close());
        await a.close();
        await b.close();
        await guestDb.close();
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      },
    );
  }
}
