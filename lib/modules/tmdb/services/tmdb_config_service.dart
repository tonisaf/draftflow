import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TmdbAccountInfo {
  final int id;
  final String username;
  final String? name;
  final String? avatarPath;

  const TmdbAccountInfo({
    required this.id,
    required this.username,
    this.name,
    this.avatarPath,
  });

  String? avatarUrl() {
    if (avatarPath == null || avatarPath!.isEmpty) return null;
    if (avatarPath!.startsWith('http')) return avatarPath;
    return 'https://image.tmdb.org/t/p/w200$avatarPath';
  }
}

class TmdbConfigService extends ChangeNotifier {
  static const _keyApiToken = 'tmdb_api_read_token';
  static const _keyKpToken = 'tmdb_kinopoisk_api_token';
  static const _keySessionId = 'tmdb_session_id';
  static const _keyAccountId = 'tmdb_account_id';
  static const _keyUsername = 'tmdb_username';
  static const _keyAvatar = 'tmdb_avatar';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  String? _apiToken;
  String? _kpApiToken;
  String? _sessionId;
  TmdbAccountInfo? _accountInfo;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get hasApiToken => _apiToken != null && _apiToken!.trim().isNotEmpty;
  bool get hasKpToken => _kpApiToken != null && _kpApiToken!.trim().isNotEmpty;
  bool get isAccountConnected => _sessionId != null && _sessionId!.isNotEmpty;

  String? get apiToken => _apiToken;
  String? get kpApiToken => _kpApiToken;
  String? get sessionId => _sessionId;
  TmdbAccountInfo? get accountInfo => _accountInfo;

  Future<void> init() async {
    try {
      try {
        _apiToken = await _secureStorage.read(key: _keyApiToken);
        _sessionId = await _secureStorage.read(key: _keySessionId);
      } catch (e) {
        debugPrint('TmdbConfigService: SecureStorage read error (using fallback): $e');
      }

      final prefs = await SharedPreferences.getInstance();
      // Fallback for API token in prefs if not in secure storage
      if (_apiToken == null || _apiToken!.isEmpty) {
        _apiToken = prefs.getString(_keyApiToken);
      }
      _kpApiToken = prefs.getString(_keyKpToken);
      if (_sessionId == null || _sessionId!.isEmpty) {
        _sessionId = prefs.getString(_keySessionId);
      }

      final accountId = prefs.getInt(_keyAccountId);
      final username = prefs.getString(_keyUsername);
      if (accountId != null && username != null) {
        _accountInfo = TmdbAccountInfo(
          id: accountId,
          username: username,
          avatarPath: prefs.getString(_keyAvatar),
        );
      }
    } catch (e) {
      debugPrint('TmdbConfigService: Error reading credentials: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setApiToken(String? token) async {
    final cleaned = token?.trim();
    _apiToken = cleaned;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (cleaned == null || cleaned.isEmpty) {
        await prefs.remove(_keyApiToken);
        try {
          await _secureStorage.delete(key: _keyApiToken);
        } catch (_) {}
      } else {
        await prefs.setString(_keyApiToken, cleaned);
        try {
          await _secureStorage.write(key: _keyApiToken, value: cleaned);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('TmdbConfigService: Error writing api token: $e');
    }
  }

  Future<void> setKpApiToken(String? token) async {
    final cleaned = token?.trim();
    _kpApiToken = cleaned;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (cleaned == null || cleaned.isEmpty) {
        await prefs.remove(_keyKpToken);
      } else {
        await prefs.setString(_keyKpToken, cleaned);
      }
    } catch (e) {
      debugPrint('TmdbConfigService: Error writing kp api token: $e');
    }
  }

  Future<void> setSession({
    required String sessionId,
    required TmdbAccountInfo accountInfo,
  }) async {
    _sessionId = sessionId;
    _accountInfo = accountInfo;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySessionId, sessionId);
      await prefs.setInt(_keyAccountId, accountInfo.id);
      await prefs.setString(_keyUsername, accountInfo.username);
      if (accountInfo.avatarPath != null) {
        await prefs.setString(_keyAvatar, accountInfo.avatarPath!);
      }
      try {
        await _secureStorage.write(key: _keySessionId, value: sessionId);
      } catch (_) {}
    } catch (e) {
      debugPrint('TmdbConfigService: Error saving session: $e');
    }
  }

  Future<void> disconnectAccount() async {
    _sessionId = null;
    _accountInfo = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySessionId);
      await prefs.remove(_keyAccountId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyAvatar);
      try {
        await _secureStorage.delete(key: _keySessionId);
      } catch (_) {}
    } catch (e) {
      debugPrint('TmdbConfigService: Error disconnecting account: $e');
    }
  }
}
