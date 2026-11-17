import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_here/services/app_update_service.dart';

void main() {
  group('AppReleaseInfo semver comparison', () {
    test('isNewer returns true when latest is greater than current', () {
      expect(AppReleaseInfo.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(AppReleaseInfo.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(AppReleaseInfo.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(AppReleaseInfo.isNewer('v1.0.1', '1.0.0'), isTrue);
      expect(AppReleaseInfo.isNewer('v1.0.1+5', '1.0.0'), isTrue);
      expect(AppReleaseInfo.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(AppReleaseInfo.isNewer('0.9.9', '1.0.0'), isFalse);
    });

    test('parses GitHub release JSON correctly and resolves platform assets', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': 'DraftFlow 1.0.1 Release',
        'body': '• Added automatic updates\n• Fixed minor bugs',
        'html_url': 'https://github.com/tonisaf/draftflow/releases/tag/v1.0.1',
        'published_at': '2026-11-17T12:00:00Z',
        'assets': [
          {
            'name': 'DraftFlow-macOS.zip',
            'browser_download_url': 'https://github.com/tonisaf/draftflow/releases/download/v1.0.1/DraftFlow-macOS.zip',
            'size': 15728640,
          },
          {
            'name': 'DraftFlow-Windows.zip',
            'browser_download_url': 'https://github.com/tonisaf/draftflow/releases/download/v1.0.1/DraftFlow-Windows.zip',
            'size': 20971520,
          },
          {
            'name': 'DraftFlow-Android-APK.apk',
            'browser_download_url': 'https://github.com/tonisaf/draftflow/releases/download/v1.0.1/DraftFlow-Android-APK.apk',
            'size': 31457280,
          },
        ],
      };

      final release = AppReleaseInfo.fromJson(json);

      expect(release.version, '1.0.1');
      expect(release.name, 'DraftFlow 1.0.1 Release');
      expect(release.notes, contains('Added automatic updates'));
      expect(release.assets.length, 3);

      final asset = release.platformAsset();
      expect(asset, isNotNull);
      expect(asset!.downloadUrl, isNotEmpty);
      expect(asset.formattedSize(), isNotEmpty);
    });
  });

  group('AppUpdateService update check workflow', () {
    test('detects available update when GitHub returns newer release', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/releases/latest')) {
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.1.0',
              'name': 'DraftFlow 1.1.0',
              'body': 'Awesome new features',
              'html_url': 'https://github.com/tonisaf/draftflow/releases/tag/v1.1.0',
              'assets': [
                {
                  'name': 'DraftFlow-macOS.zip',
                  'browser_download_url': 'https://github.com/tonisaf/draftflow/releases/download/v1.1.0/DraftFlow-macOS.zip',
                  'size': 12345678,
                }
              ],
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(client: mockClient);
      expect(service.status, UpdateCheckStatus.idle);

      final release = await service.checkForUpdates();
      expect(release, isNotNull);
      expect(service.hasUpdate, isTrue);
      expect(service.status, UpdateCheckStatus.updateAvailable);
      expect(service.latestRelease?.version, '1.1.0');
    });

    test('reports upToDate when release tag matches or is older', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.0.0',
            'name': 'DraftFlow 1.0.0',
            'body': 'Initial version',
            'html_url': 'https://github.com/tonisaf/draftflow/releases/tag/v1.0.0',
            'assets': [],
          }),
          200,
        );
      });

      final service = AppUpdateService(client: mockClient);
      final release = await service.checkForUpdates();

      expect(release, isNotNull);
      expect(service.hasUpdate, isFalse);
      expect(service.status, UpdateCheckStatus.upToDate);
    });
  });
}
