import 'sync_outbox.dart';

class RemoteChange {
  const RemoteChange({
    required this.seq,
    required this.operationId,
    required this.deviceId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
  });
  final int seq;
  final String operationId, deviceId, entityType, entityId, action;
  final Map<String, dynamic> payload;
  factory RemoteChange.fromJson(Map<String, dynamic> row) => RemoteChange(
    seq: (row['seq_id'] as num).toInt(),
    operationId: row['operation_id'] as String,
    deviceId: row['device_id'] as String,
    entityType: row['entity_type'] as String,
    entityId: row['entity_id'] as String,
    action: row['action'] as String,
    payload: Map<String, dynamic>.from(row['payload'] as Map),
  );
}

abstract interface class NotesSyncTransport {
  Future<void> push(String deviceId, List<PendingChange> changes);
  Future<List<RemoteChange>> pull(int after);
}

class SyncFailure implements Exception {
  const SyncFailure(this.message);
  final String message;
}

class SyncSetupRequired extends SyncFailure {
  const SyncSetupRequired() : super('Сервер синхронизации ещё не настроен.');
}

class SyncAuthRequired extends SyncFailure {
  const SyncAuthRequired() : super('Для синхронизации войдите повторно.');
}

class SyncOffline extends SyncFailure {
  const SyncOffline()
    : super('Нет соединения. Изменения сохранены на устройстве.');
}

class SyncRejected extends SyncFailure {
  const SyncRejected(this.entityType, this.entityId)
    : super('Версия на сервере изменилась.');
  final String entityType, entityId;
}
