import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preconfigured default Supabase instance.
const defaultSupabaseUrl = 'https://ylahgnfkwtmokvctmzmq.supabase.co';
const defaultSupabaseAnonKey =
    'sb_publishable_vphxKJMg3WXViHr3Fze8Ew_L-QqHy99';

/// Backend sync server configuration (URL + anon API key).
@immutable
class ServerConfig {
  const ServerConfig({required this.url, required this.key});

  final String url;
  final String key;

  String get host {
    final uri = Uri.tryParse(url);
    return uri?.host.isNotEmpty == true ? uri!.host : url;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          key == other.key;

  @override
  int get hashCode => Object.hash(url, key);
}

/// Normalizes whatever was pasted ("https://x.supabase.co/rest/v1/") to the
/// server origin (scheme://host[:port]).
String normalizeServerUrl(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty) return text;
  return Uri(
    scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}

/// Persistent store for custom server configuration via SharedPreferences.
class ServerConfigStore {
  static const _prefUrlKey = 'sync_server_url';
  static const _prefAnonKey = 'sync_server_anon_key';

  static Future<ServerConfig?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_prefUrlKey)?.trim();
      final key = prefs.getString(_prefAnonKey)?.trim();

      if (url != null && url.isNotEmpty && key != null && key.isNotEmpty) {
        return ServerConfig(url: normalizeServerUrl(url), key: key);
      }
    } catch (e) {
      debugPrint('ServerConfigStore: Failed to load server config: $e');
    }

    // Check compile-time environment variables
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (envUrl.isNotEmpty && envKey.isNotEmpty) {
      return ServerConfig(url: normalizeServerUrl(envUrl), key: envKey);
    }

    // Fallback to preconfigured default Supabase instance
    if (defaultSupabaseUrl.isNotEmpty && defaultSupabaseAnonKey.isNotEmpty) {
      return const ServerConfig(
        url: defaultSupabaseUrl,
        key: defaultSupabaseAnonKey,
      );
    }

    return null;
  }

  static Future<void> save(ServerConfig? config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (config == null) {
        await prefs.remove(_prefUrlKey);
        await prefs.remove(_prefAnonKey);
      } else {
        await prefs.setString(_prefUrlKey, config.url);
        await prefs.setString(_prefAnonKey, config.key);
      }
    } catch (e) {
      debugPrint('ServerConfigStore: Failed to save server config: $e');
    }
  }
}
