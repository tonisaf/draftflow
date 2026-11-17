import 'dart:convert';

import 'package:notes_here/sync/sync_outbox.dart';
import 'package:notes_here/sync/sync_types.dart';

/// In-memory implementation of the server contract, not a production transport.
/// SQL/RLS must additionally be exercised in Postgres before live rollout.
class SyncTestServer {
  final log = <RemoteChange>[];
  bool loseResponse = false;
  bool offline = false;
  Future<void> Function()? beforePush;
  Future<void> push(String device, List<PendingChange> batch) async {
    if (offline) throw const SyncOffline();
    await beforePush?.call();
    final staged = List<RemoteChange>.of(log);
    for (final op in batch) {
      final same = staged.where((e) => e.operationId == op.operationId);
      if (same.isNotEmpty) continue;
      final history = staged.where(
        (e) => e.entityType == op.entityType && e.entityId == op.entityId,
      );
      final base = history.lastOrNull?.seq ?? 0;
      if (base != op.baseSeq) throw SyncRejected(op.entityType, op.entityId);
      staged.add(
        RemoteChange(
          seq: staged.length + 1,
          operationId: op.operationId,
          deviceId: device,
          entityType: op.entityType,
          entityId: op.entityId,
          action: op.action,
          payload: Map<String, dynamic>.from(jsonDecode(op.payload) as Map),
        ),
      );
    }
    log
      ..clear()
      ..addAll(staged);
    if (loseResponse) {
      loseResponse = false;
      throw const SyncOffline();
    }
  }
}

class MemoryNotesTransport implements NotesSyncTransport {
  MemoryNotesTransport(this.server, {this.pageSize = 100});
  final SyncTestServer server;
  final int pageSize;
  @override
  Future<void> push(String deviceId, List<PendingChange> changes) =>
      server.push(deviceId, changes);
  @override
  Future<List<RemoteChange>> pull(int after) async {
    if (server.offline) throw const SyncOffline();
    return server.log.where((e) => e.seq > after).take(pageSize).toList();
  }
}
