import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/account/session_store.dart';

class MockSecureStorage extends FlutterSecureStorage {
  MockSecureStorage({this.throwOnRead = false, this.throwOnWrite = false});

  bool throwOnRead;
  bool throwOnWrite;
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnRead) throw Exception('Keychain access denied');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnWrite) throw Exception('Keychain write error');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (throwOnWrite) throw Exception('Keychain delete error');
    values.remove(key);
  }
}

void main() {
  late Directory tempDir;
  late MockSecureStorage mockSecure;
  late FileSessionStore fileStore;
  late SecureSessionStore sessionStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_store_test_');
    mockSecure = MockSecureStorage();
    fileStore = FileSessionStore('test_session.json', getDirectory: () async => tempDir);
    sessionStore = SecureSessionStore(
      'example.supabase.co',
      storage: mockSecure,
      fallback: fileStore,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writes to secure storage when available and cleans up fallback', () async {
    await fileStore.write('legacy_token');
    expect(await fileStore.read(), 'legacy_token');

    await sessionStore.write('new_secure_token');

    expect(mockSecure.values['notes_here.auth.example.supabase.co'], 'new_secure_token');
    expect(await fileStore.read(), isNull);
    expect(await sessionStore.read(), 'new_secure_token');
  });

  test('transparently falls back to file store when secure storage throws on write', () async {
    mockSecure.throwOnWrite = true;

    // Should NOT throw exception
    await sessionStore.write('fallback_token');

    expect(await fileStore.read(), 'fallback_token');
    expect(await sessionStore.read(), 'fallback_token');
  });

  test('transparently migrates from fallback to secure storage when secure storage becomes available', () async {
    await fileStore.write('cached_fallback_session');
    expect(mockSecure.values, isEmpty);

    final readValue = await sessionStore.read();
    expect(readValue, 'cached_fallback_session');

    // Should have migrated into secure storage and cleaned up fallback
    expect(mockSecure.values['notes_here.auth.example.supabase.co'], 'cached_fallback_session');
    expect(await fileStore.read(), isNull);
  });

  test('deletes from both secure storage and fallback on logout', () async {
    mockSecure.values['notes_here.auth.example.supabase.co'] = 'token';
    await fileStore.write('token');

    await sessionStore.write(null);

    expect(mockSecure.values['notes_here.auth.example.supabase.co'], isNull);
    expect(await fileStore.read(), isNull);
    expect(await sessionStore.read(), isNull);
  });
}
