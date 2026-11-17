import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase/supabase.dart';

import 'sync_outbox.dart';
import 'sync_types.dart';

class SupabaseNotesTransport implements NotesSyncTransport {
  SupabaseNotesTransport(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _checkIdentity() {
    if (client.auth.currentUser?.id != userId ||
        client.auth.currentSession == null ||
        client.auth.currentSession!.isExpired) {
      throw const SyncAuthRequired();
    }
  }

  Future<T> _request<T>(Future<T> Function() action) async {
    _checkIdentity();
    try {
      final result = await action().timeout(const Duration(seconds: 20));
      _checkIdentity();
      return result;
    } on PostgrestException catch (e) {
      if (['42P01', 'PGRST202', 'PGRST205', '42883'].contains(e.code)) {
        throw const SyncSetupRequired();
      }
      if (['42501', 'PGRST301', 'PGRST303'].contains(e.code)) {
        throw const SyncAuthRequired();
      }
      if (e.code == 'PT409') {
        try {
          final details = jsonDecode(e.details as String) as Map;
          throw SyncRejected(
            details['entity_type'] as String,
            details['entity_id'] as String,
          );
        } on SyncRejected {
          rethrow;
        } catch (_) {
          throw const SyncFailure(
            'Структура заметок изменилась на сервере. Обновите данные и повторите.',
          );
        }
      }
      throw const SyncFailure(
        'Сервер не принял изменения. Локальная очередь сохранена.',
      );
    } on SocketException {
      throw const SyncOffline();
    } on ClientException {
      throw const SyncOffline();
    } on TimeoutException {
      throw const SyncOffline();
    } on AuthException {
      throw const SyncAuthRequired();
    }
  }

  @override
  Future<List<RemoteChange>> pull(int after) => _request(() async {
    final token = client.auth.currentSession!.accessToken;
    final data = await client
        .from('notes_sync_events')
        .select(
          'seq_id,operation_id,device_id,entity_type,entity_id,action,payload',
        )
        .eq('user_id', userId)
        .gt('seq_id', after)
        .order('seq_id', ascending: true)
        .limit(100)
        .setHeader('Authorization', 'Bearer $token');
    return [for (final row in data) RemoteChange.fromJson(row)];
  });
  @override
  Future<void> push(String deviceId, List<PendingChange> changes) =>
      _request(() async {
        final token = client.auth.currentSession!.accessToken;
        await client
            .rpc(
              'notes_sync_push_v2',
              params: {
                'p_device_id': deviceId,
                'p_events': [for (final change in changes) change.toJson()],
              },
            )
            .setHeader('Authorization', 'Bearer $token');
      });
}
