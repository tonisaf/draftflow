import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';

import 'sync_store.dart';
import 'sync_types.dart';

enum NotesSyncPhase {
  ready,
  syncing,
  synced,
  offline,
  conflict,
  setupRequired,
  authRequired,
  error,
}

class NotesSyncEngine extends ChangeNotifier {
  NotesSyncEngine({
    required this.store,
    required this.transport,
    this.onRemoteApplied,
    this.applyRemote,
    this.pollInterval = const Duration(seconds: 20),
    this.debounce = const Duration(milliseconds: 800),
  });
  final SyncStore store;
  final NotesSyncTransport transport;
  final VoidCallback? onRemoteApplied;
  final Future<bool> Function(Future<bool> Function())? applyRemote;
  final Duration pollInterval, debounce;
  NotesSyncPhase phase = NotesSyncPhase.ready;
  String? message;
  int pending = 0, conflictCount = 0;
  DateTime? lastSync;
  Timer? _poll, _debounce;
  StreamSubscription? _writes;
  Future<void>? _running;
  bool _closed = false;
  void start() {
    if (_closed || _writes != null) return;
    final db = store.db;
    _writes = db
        .tableUpdates(
          TableUpdateQuery.allOf([
            TableUpdateQuery.onTable(db.pages),
            TableUpdateQuery.onTable(db.blocks),
            TableUpdateQuery.onTable(db.databases),
            TableUpdateQuery.onTable(db.databaseColumns),
          ]),
        )
        .listen((_) {
          if (_running != null) return;
          phase = NotesSyncPhase.ready;
          _notify();
          _debounce?.cancel();
          _debounce = Timer(debounce, () => unawaited(sync()));
        });
    _poll = Timer.periodic(pollInterval, (_) => unawaited(sync()));
    unawaited(sync());
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> sync() {
    if (_closed) return Future.value();
    return _running ??= _cycle().whenComplete(() => _running = null);
  }

  Future<void> _pull() async {
    while (!_closed) {
      final events = await transport.pull(await store.cursor);
      if (_closed || events.isEmpty) return;
      final changed = await (applyRemote == null
          ? store.receive(events)
          : applyRemote!(() => store.receive(events)));
      if (changed && !_closed) onRemoteApplied?.call();
    }
  }

  Future<void> _cycle() async {
    phase = NotesSyncPhase.syncing;
    message = null;
    _notify();
    try {
      await _pull();
      while (!_closed) {
        final conflicts = await store.conflicts();
        if (conflicts.isNotEmpty) {
          phase = NotesSyncPhase.conflict;
          break;
        }
        final batch = await store.uploadBatch();
        if (batch.isEmpty) {
          phase = NotesSyncPhase.synced;
          lastSync = DateTime.now();
          break;
        }
        try {
          await transport.push(await store.deviceId, batch);
        } on SyncRejected catch (e) {
          await _pull();
          if (_closed) return;
          if ((await store.conflicts()).isEmpty) {
            await store.rejected(e.entityType, e.entityId);
          }
          phase = NotesSyncPhase.conflict;
          break;
        }
        if (_closed) return;
        final before = await store.cursor;
        // Ack only through the incoming journal, including after a lost response.
        await _pull();
        if (!_closed && await store.cursor == before) {
          throw const SyncFailure(
            'Сервер не подтвердил изменения. Очередь сохранена для повтора.',
          );
        }
      }
    } on SyncSetupRequired catch (e) {
      phase = NotesSyncPhase.setupRequired;
      message = e.message;
    } on SyncAuthRequired catch (e) {
      phase = NotesSyncPhase.authRequired;
      message = e.message;
    } on SyncOffline catch (e) {
      phase = NotesSyncPhase.offline;
      message = e.message;
    } on SyncFailure catch (e) {
      phase = NotesSyncPhase.error;
      message = e.message;
    } catch (_) {
      phase = NotesSyncPhase.error;
      message = 'Не удалось синхронизировать. Локальные изменения сохранены.';
    } finally {
      if (!_closed) {
        pending = await store.pendingCount;
        conflictCount = (await store.conflicts()).length;
        _notify();
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    _debounce?.cancel();
    await _writes?.cancel();
    await _running;
    super.dispose();
  }
}
