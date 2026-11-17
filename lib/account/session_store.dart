import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String? session);
}

/// Fallback file store located in the application support directory.
class FileSessionStore implements SessionStore {
  FileSessionStore(this.fileName, {Future<Directory> Function()? getDirectory})
      : _getDirectory = getDirectory ?? getApplicationSupportDirectory;

  final String fileName;
  final Future<Directory> Function() _getDirectory;

  Future<File> _file() async {
    final dir = await _getDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<String?> read() async {
    try {
      final file = await _file();
      return file.existsSync() ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? session) async {
    try {
      final file = await _file();
      if (session == null) {
        if (file.existsSync()) await file.delete();
      } else {
        await file.writeAsString(session, flush: true);
      }
    } catch (_) {
      // Ignored: fallback write failure
    }
  }
}

/// OS-protected vault (macOS Keychain, Windows DPAPI / Credential Manager,
/// Android KeyStore, iOS Keychain) backed by [FlutterSecureStorage], with transparent
/// fallback to [FileSessionStore] if OS vault is restricted or unavailable.
class SecureSessionStore implements SessionStore {
  SecureSessionStore(
    String projectHost, {
    FlutterSecureStorage? storage,
    SessionStore? fallback,
  })  : _key = 'notes_here.auth.$projectHost',
        _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            ),
        _fallback = fallback ??
            FileSessionStore(
              'auth_session_${projectHost.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}.json',
            );

  final String _key;
  final FlutterSecureStorage _storage;
  final SessionStore _fallback;

  @override
  Future<String?> read() async {
    // 1. Try OS secure storage first.
    try {
      final secureValue = await _storage.read(key: _key);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } on Object {
      // OS secure storage unavailable or errored.
    }

    // 2. Check fallback file in app support folder.
    try {
      final fallbackValue = await _fallback.read();
      if (fallbackValue != null && fallbackValue.isNotEmpty) {
        // Transparent migration: try migrating fallback session into secure storage.
        try {
          await _storage.write(key: _key, value: fallbackValue);
          await _fallback.write(null);
        } on Object {
          // If writing to secure storage fails, continue serving from fallback.
        }
        return fallbackValue;
      }
    } on Object {
      // Fallback read error ignored.
    }

    return null;
  }

  @override
  Future<void> write(String? session) async {
    if (session == null) {
      try {
        await _storage.delete(key: _key);
      } on Object {
        // Secure storage delete failure ignored on clean-up.
      }
      try {
        await _fallback.write(null);
      } on Object {
        // Fallback delete failure ignored on clean-up.
      }
      return;
    }

    try {
      await _storage.write(key: _key, value: session);
      // Once written to secure storage, remove any fallback leftover.
      try {
        await _fallback.write(null);
      } on Object {
        // Fallback cleanup failure ignored.
      }
    } on Object {
      // In dev mode or when OS secure storage is unavailable, transparently fall back.
      await _fallback.write(session);
    }
  }
}
