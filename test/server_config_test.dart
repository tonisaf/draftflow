import 'package:flutter_test/flutter_test.dart';
import 'package:notes_here/account/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ServerConfig and normalizeServerUrl', () {
    test('normalizeServerUrl cleans up standard URLs', () {
      expect(
        normalizeServerUrl('https://xyz.supabase.co'),
        'https://xyz.supabase.co',
      );
      expect(
        normalizeServerUrl('https://xyz.supabase.co/rest/v1/'),
        'https://xyz.supabase.co',
      );
      expect(
        normalizeServerUrl('https://xyz.supabase.co/auth/v1/callback?param=1#frag'),
        'https://xyz.supabase.co',
      );
    });

    test('normalizeServerUrl adds https scheme when missing', () {
      expect(
        normalizeServerUrl('myproject.supabase.co'),
        'https://myproject.supabase.co',
      );
      expect(
        normalizeServerUrl('  myproject.supabase.co/rest/v1  '),
        'https://myproject.supabase.co',
      );
    });

    test('normalizeServerUrl handles self-hosted http and ports', () {
      expect(
        normalizeServerUrl('http://localhost:54321/auth/v1'),
        'http://localhost:54321',
      );
      expect(
        normalizeServerUrl('http://192.168.1.100:8000/rest/v1'),
        'http://192.168.1.100:8000',
      );
    });

    test('ServerConfig extracts host correctly', () {
      const config = ServerConfig(
        url: 'https://xyz.supabase.co',
        key: 'anon_key_123',
      );
      expect(config.host, 'xyz.supabase.co');

      const localConfig = ServerConfig(
        url: 'http://localhost:54321',
        key: 'local_anon_key',
      );
      expect(localConfig.host, 'localhost');
    });

    test('ServerConfigStore persists and clears config', () async {
      SharedPreferences.setMockInitialValues({});

      // Initially null
      final initial = await ServerConfigStore.load();
      expect(initial, isNull);

      // Save custom config
      const toSave = ServerConfig(
        url: 'https://custom.supabase.co',
        key: 'custom_key_456',
      );
      await ServerConfigStore.save(toSave);

      final loaded = await ServerConfigStore.load();
      expect(loaded, isNotNull);
      expect(loaded!.url, 'https://custom.supabase.co');
      expect(loaded.key, 'custom_key_456');

      // Clear
      await ServerConfigStore.save(null);
      final cleared = await ServerConfigStore.load();
      expect(cleared, isNull);
    });
  });
}
