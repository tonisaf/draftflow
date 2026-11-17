import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:notes_here/account/supabase_account_auth.dart';
import 'package:notes_here/sync/supabase_notes_transport.dart';
import 'package:notes_here/sync/sync_outbox.dart';
import 'package:notes_here/sync/sync_types.dart';

import 'account_auth_test.dart' show MemorySessionStore, sessionJson, userId;

void main() {
  late SupabaseClient client;
  late SupabaseAccountAuth auth;
  late SupabaseNotesTransport transport;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) rest;
  setUp(() {
    requests = [];
    rest = (_) async => http.Response('[]', 200);
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/auth/')) {
          return http.Response(jsonEncode(sessionJson()), 200);
        }
        requests.add(request);
        final response = await rest(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: {'content-type': 'application/json', ...response.headers},
          request: request,
        );
      }),
    );
    auth = SupabaseAccountAuth(client: client, store: MemorySessionStore());
    transport = SupabaseNotesTransport(client, userId);
  });
  tearDown(() => auth.dispose());
  test('signed-out requests are blocked before touching the backend', () async {
    await expectLater(transport.pull(0), throwsA(isA<SyncAuthRequired>()));
    expect(requests, isEmpty);
  });
  test('wrong account cannot upload this repository data', () async {
    await auth.signIn('test@example.com', 'password');
    final wrong = SupabaseNotesTransport(client, 'other-user');
    await expectLater(
      wrong.push('device', [
        const PendingChange('op', 'pages', 'p', 'UPSERT', '{}'),
      ]),
      throwsA(isA<SyncAuthRequired>()),
    );
    expect(requests, isEmpty);
  });
  test(
    'pull filters by owner, cursor and ascending sequence with a bounded page',
    () async {
      await auth.signIn('test@example.com', 'password');
      await transport.pull(42);
      final request = requests.single;
      expect(request.url.path, '/rest/v1/notes_sync_events');
      expect(request.url.queryParameters['user_id'], 'eq.$userId');
      expect(request.url.queryParameters['seq_id'], 'gt.42');
      expect(request.url.queryParameters['order'], startsWith('seq_id.asc'));
      expect(request.url.queryParameters['limit'], '100');
    },
  );
  test(
    'upload uses v2 RPC with immutable operation ID and base version',
    () async {
      await auth.signIn('test@example.com', 'password');
      await transport.push('device', [
        const PendingChange(
          'operation',
          'pages',
          'p',
          'UPSERT',
          '{"id":"p"}',
          baseSeq: 12,
          seenSeq: 40,
        ),
      ]);
      final request = requests.single;
      expect(request.url.path, '/rest/v1/rpc/notes_sync_push_v2');
      expect(
        request.headers['Authorization'] ?? request.headers['authorization'],
        'Bearer ${client.auth.currentSession!.accessToken}',
      );
      final body = jsonDecode(request.body) as Map;
      expect(body['p_device_id'], 'device');
      final event = (body['p_events'] as List).single as Map;
      expect(event['operation_id'], 'operation');
      expect(event['base_seq'], 12);
      expect(event['seen_seq'], 40);
      expect(event.containsKey('user_id'), isFalse);
    },
  );
  test('missing schema has a distinct actionable state', () async {
    await auth.signIn('test@example.com', 'password');
    rest = (_) async => http.Response(
      jsonEncode({
        'code': 'PGRST202',
        'message': 'Missing RPC',
        'details': null,
        'hint': null,
      }),
      404,
    );
    await expectLater(
      transport.push('device', []),
      throwsA(isA<SyncSetupRequired>()),
    );
  });
  test(
    'server conflict identifies the rejected entity without leaking raw errors',
    () async {
      await auth.signIn('test@example.com', 'password');
      rest = (_) async => http.Response(
        jsonEncode({
          'code': 'PT409',
          'message': 'notes_sync_conflict',
          'details': jsonEncode({'entity_type': 'pages', 'entity_id': 'p'}),
          'hint': null,
        }),
        409,
      );
      await expectLater(
        transport.push('device', []),
        throwsA(isA<SyncRejected>().having((e) => e.entityId, 'entity', 'p')),
      );
    },
  );
}
