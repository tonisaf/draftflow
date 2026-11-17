import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String? session);
}

/// Fail closed if the OS vault is unavailable. Never use a plaintext fallback.
class SecureSessionStore implements SessionStore {
  SecureSessionStore(String projectHost, {FlutterSecureStorage? storage})
    : _key = 'notes_here.auth.$projectHost',
      _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: true),
          );
  final String _key;
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? session) => session == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: session);
}
