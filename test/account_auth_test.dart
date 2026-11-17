import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:notes_here/account/account_controller.dart';
import 'package:notes_here/account/session_store.dart';
import 'package:notes_here/account/supabase_account_auth.dart';

class MemorySessionStore implements SessionStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async {
    if (fail) throw StateError('vault');
    return value;
  }

  @override
  Future<void> write(String? session) async {
    if (fail) throw StateError('vault');
    value = session;
  }
}

const userId = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';
Map<String, dynamic> sessionJson({bool expired = false}) => {
  'access_token':
      '${base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '')}.${base64Url.encode(utf8.encode(jsonEncode({'sub': userId, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -3600 : 3600)}))).replaceAll('=', '')}.test-signature',
  'refresh_token': 'test-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -3600 : 3600),
  'user': {
    'id': userId,
    'email': 'test@example.com',
    'aud': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z',
    'app_metadata': {},
    'user_metadata': {},
  },
};
void main() {
  late SupabaseAccountAuth auth;
  late MemorySessionStore store;
  var requests = 0;
  late Future<http.Response> Function(http.Request) respond;
  setUp(() {
    requests = 0;
    store = MemorySessionStore();
    respond = (_) async => http.Response(jsonEncode(sessionJson()), 200);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) {
        requests++;
        return respond(request);
      }),
    );
    auth = SupabaseAccountAuth(client: client, store: store);
  });
  tearDown(() => auth.dispose());
  test(
    'sign-in persists session and returns identity; password is not persisted',
    () async {
      final account = await auth.signIn('test@example.com', 'test-password');
      expect(account.id, userId);
      expect(store.value, contains('test-refresh'));
      expect(store.value, isNot(contains('test-password')));
    },
  );
  test('vault failure prevents successful sign-in', () async {
    store.fail = true;
    await expectLater(
      auth.signIn('test@example.com', 'password'),
      throwsA(isA<AccountFailure>()),
    );
  });
  test(
    'expired cached session permits local work without network or deletion',
    () async {
      store.value = jsonEncode(sessionJson(expired: true));
      final account = await auth.restore();
      expect(account?.id, userId);
      expect(account?.requiresSignIn, isTrue);
      expect(requests, 0);
      expect(store.value, isNotNull);
    },
  );
  test('malformed cached session is cleared', () async {
    store.value = 'broken-json';
    expect(await auth.restore(), isNull);
    expect(store.value, isNull);
    expect(requests, 0);
  });
  test(
    'vault read failure is reported instead of exposing a cached account',
    () async {
      store.fail = true;
      await expectLater(auth.restore(), throwsA(isA<AccountFailure>()));
    },
  );
  test('local signout succeeds even if remote revocation fails', () async {
    await auth.signIn('test@example.com', 'password');
    respond = (_) async => http.Response('{"message":"Unavailable"}', 503);
    await auth.signOut();
    expect(store.value, isNull);
  });
  test('vault delete failure does not claim successful signout', () async {
    await auth.signIn('test@example.com', 'password');
    store.fail = true;
    await expectLater(auth.signOut(), throwsStateError);
    expect(store.value, isNotNull);
    store.fail = false;
  });
}
