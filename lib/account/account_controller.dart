import '../services/database_cell_saves.dart';
import '../sync/account_sync_provider.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_store.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/db/app_database.dart';
import '../data/notes_repository.dart';
import '../sync/sync_outbox.dart';

class NotesIdentity {
  const NotesIdentity(this.id, this.email, {this.requiresSignIn = false});
  final String id;
  final String email;
  final bool requiresSignIn;
}

abstract interface class AccountAuth {
  Stream<NotesIdentity?> get changes;
  Future<NotesIdentity?> restore();
  Future<NotesIdentity> signIn(String email, String password);
  Future<NotesIdentity?> signUp(String email, String password);
  Future<void> signOut();
  Future<void> dispose();
}

/// Owns account boundaries; database handles remain alive for late writes from
/// disposed widgets, always to their original workspace. No guest data is copied.
class AccountController extends ChangeNotifier {
  AccountController({
    required NotesRepository guest,
    this.auth,
    Future<NotesRepository> Function(String)? openAccount,
    this.waitForEditorFrame,
    this.afterRemoteApply,
  }) : repository = guest,
       _guest = guest,
       _open = openAccount ?? _openDefault {
    _subscription = auth?.changes.listen(
      (identity) {
        if (busy) {
          _hasPendingIdentity = true;
          _pendingIdentity = identity;
        } else if (identity?.id != account?.id) {
          unawaited(_run(() => _switch(identity)));
        }
      },
      onError: (Object _) {
        _setError('Не удалось обновить состояние аккаунта.');
      },
    );
  }
  static Future<NotesRepository> _openDefault(String id) async {
    final db = AppDatabase.forAccount(id);
    try {
      await SyncOutbox(db).enable();
      return NotesRepository(db);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  final AccountAuth? auth;
  final Future<void> Function()? waitForEditorFrame;
  final VoidCallback? afterRemoteApply;
  bool applyingRemote = false;
  Set<String> syncChangedPages = {};
  final NotesRepository _guest;
  final Future<NotesRepository> Function(String) _open;
  final _accounts = <String, NotesRepository>{};
  final _savers = <Future<void> Function()>{};
  StreamSubscription<NotesIdentity?>? _subscription;
  NotesRepository repository;
  NotesIdentity? account;
  bool busy = false;
  NotesSyncEngine? syncEngine;
  int syncRevision = 0;
  String? error;
  String? notice;
  bool _disposed = false;
  bool _hasPendingIdentity = false;
  NotesIdentity? _pendingIdentity;
  bool get configured => auth != null;
  void registerSaver(Future<void> Function() save) => _savers.add(save);
  void unregisterSaver(Future<void> Function() save) => _savers.remove(save);
  void _setError(String message) {
    error = message;
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await _stopSync();
      await action();
      return true;
    } on AccountFailure catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Не удалось выполнить действие. Данные сохранены в текущем пространстве.';
      return false;
    } finally {
      busy = false;
      if (!_disposed) _startSync();
      if (!_disposed) notifyListeners();
      if (_hasPendingIdentity && !_disposed) {
        final next = _pendingIdentity;
        _hasPendingIdentity = false;
        unawaited(_run(() => _switch(next)));
      }
    }
  }

  Future<void> _stopSync() async {
    final old = syncEngine;
    syncEngine = null;
    old?.removeListener(_syncChanged);
    await old?.close();
  }

  void _syncChanged() {
    if (!_disposed) notifyListeners();
  }

  void _startSync() {
    final provider = auth is AccountSyncProvider
        ? auth as AccountSyncProvider
        : null;
    final identity = account;
    if (syncEngine != null ||
        provider == null ||
        identity == null ||
        identity.requiresSignIn ||
        !provider.canSync(identity.id)) {
      return;
    }
    syncEngine = provider.createSync(repository, identity.id, () {
      syncRevision++;
      syncChangedPages = Set.of(syncEngine?.store.changedPages ?? {});
      if (!_disposed) notifyListeners();
    }, _applyRemote);
    syncEngine!.addListener(_syncChanged);
    syncEngine!.start();
  }

  Future<bool> _applyRemote(Future<bool> Function() apply) async {
    if (_disposed) return false;
    applyingRemote = true;
    notifyListeners();
    try {
      if (_savers.isNotEmpty) await waitForEditorFrame?.call();
      await _flush();
      return await apply();
    } finally {
      applyingRemote = false;
      if (!_disposed) {
        notifyListeners();
        afterRemoteApply?.call();
      }
    }
  }

  Future<bool> resolveSyncConflict(
    SyncConflict reviewed, {
    required bool useLocal,
  }) => _run(() async {
    await _flush();
    await SyncStore(repository.db).resolve(reviewed, useLocal: useLocal);
    syncRevision++;
    syncChangedPages = reviewed.entityType == 'blocks'
        ? {reviewed.remote['page_id'] as String}
        : {};
  });

  Future<void> _flush() async {
    for (final save in List.of(_savers)) {
      await save();
    }
    if (!await DatabaseCellSaves.forRepository(repository).flush()) {
      throw const AccountFailure(
        'Не удалось сохранить ячейки таблицы. Вернитесь к таблице, исправьте ввод, разрешите конфликты или повторите сохранение.',
      );
    }
  }

  Future<void> _switch(NotesIdentity? identity) async {
    if (identity?.id == account?.id) {
      account = identity;
      return;
    }
    await _flush();
    final target = identity == null
        ? _guest
        : (_accounts[identity.id] ??= await _open(identity.id));
    repository = target;
    account = identity;
  }

  Future<bool> restore() => _run(() async {
    if (auth != null) await _switch(await auth!.restore());
  });
  Future<bool> signIn(String email, String password) => _run(() async {
    if (auth == null) throw const AccountFailure('Вход пока не настроен.');
    await _flush();
    await _switch(await auth!.signIn(email.trim(), password));
  });
  Future<bool> signUp(String email, String password) => _run(() async {
    if (auth == null) throw const AccountFailure('Вход пока не настроен.');
    await _flush();
    final identity = await auth!.signUp(email.trim(), password);
    if (identity == null) {
      notice = 'Подтвердите email по ссылке из письма, затем войдите.';
    } else {
      await _switch(identity);
    }
  });
  Future<bool> signOut() => _run(() async {
    await _flush();
    await auth?.signOut();
    await _switch(null);
  });
  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_stopSync().then((_) => auth?.dispose()));
    // Widget-owned repositories can still have captured async writes in flight.
    // They are deliberately not closed during a workspace switch.
    super.dispose();
  }
}

class AccountFailure implements Exception {
  const AccountFailure(this.message);
  final String message;
}
