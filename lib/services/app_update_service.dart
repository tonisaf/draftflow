import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../modules/core/url_utils.dart';

const String currentAppVersion = '1.0.0';
const String gitHubRepoOwner = 'tonisaf';
const String gitHubRepoName = 'draftflow';

class ReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;

  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }

  String formattedSize() {
    if (size <= 0) return '';
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AppReleaseInfo {
  final String tagName;
  final String version;
  final String name;
  final String notes;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawTag = json['tag_name'] as String? ?? '';
    final cleanVersion = rawTag.replaceFirst(RegExp(r'^[vV]'), '').trim();

    final rawAssets = json['assets'] as List<dynamic>? ?? [];
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map(ReleaseAsset.fromJson)
        .toList();

    DateTime? published;
    if (json['published_at'] != null) {
      published = DateTime.tryParse(json['published_at'] as String);
    }

    return AppReleaseInfo(
      tagName: rawTag,
      version: cleanVersion.isNotEmpty ? cleanVersion : rawTag,
      name: json['name'] as String? ?? rawTag,
      notes: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? 'https://github.com/$gitHubRepoOwner/$gitHubRepoName/releases',
      publishedAt: published,
      assets: assets,
    );
  }

  ReleaseAsset? platformAsset() {
    if (assets.isEmpty) return null;

    if (Platform.isMacOS) {
      return assets.firstWhere(
        (a) => a.name.toLowerCase().contains('mac') && a.name.endsWith('.zip'),
        orElse: () => assets.firstWhere(
          (a) => a.name.endsWith('.zip') || a.name.endsWith('.dmg'),
          orElse: () => assets.first,
        ),
      );
    } else if (Platform.isWindows) {
      return assets.firstWhere(
        (a) => a.name.toLowerCase().contains('win') && a.name.endsWith('.zip'),
        orElse: () => assets.firstWhere(
          (a) => a.name.endsWith('.zip') || a.name.endsWith('.exe') || a.name.endsWith('.msix'),
          orElse: () => assets.first,
        ),
      );
    } else if (Platform.isAndroid) {
      return assets.firstWhere(
        (a) => a.name.endsWith('.apk'),
        orElse: () => assets.first,
      );
    }

    return assets.first;
  }

  static bool isNewer(String latest, String current) {
    final vLatest = _parseSemver(latest);
    final vCurrent = _parseSemver(current);

    for (var i = 0; i < 3; i++) {
      if (vLatest[i] > vCurrent[i]) return true;
      if (vLatest[i] < vCurrent[i]) return false;
    }
    return false;
  }

  static List<int> _parseSemver(String raw) {
    final clean = raw.replaceFirst(RegExp(r'^[vV]'), '').split('-').first.split('+').first;
    final parts = clean.split('.');
    final result = <int>[0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
      result[i] = int.tryParse(parts[i]) ?? 0;
    }
    return result;
  }
}

enum UpdateCheckStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  downloaded,
  error,
}

class AppUpdateService extends ChangeNotifier {
  final http.Client _client;
  UpdateCheckStatus _status = UpdateCheckStatus.idle;
  AppReleaseInfo? _latestRelease;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;
  String? _errorMessage;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  UpdateCheckStatus get status => _status;
  AppReleaseInfo? get latestRelease => _latestRelease;
  double get downloadProgress => _downloadProgress;
  String? get downloadedFilePath => _downloadedFilePath;
  String? get errorMessage => _errorMessage;

  bool get hasUpdate =>
      _latestRelease != null &&
      AppReleaseInfo.isNewer(_latestRelease!.version, currentAppVersion);

  Future<AppReleaseInfo?> checkForUpdates({bool manual = false}) async {
    _status = UpdateCheckStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$gitHubRepoOwner/$gitHubRepoName/releases/latest',
      );

      final res = await _client.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'DraftFlow-App-Updater',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final release = AppReleaseInfo.fromJson(data);
        _latestRelease = release;

        if (AppReleaseInfo.isNewer(release.version, currentAppVersion)) {
          _status = UpdateCheckStatus.updateAvailable;
        } else {
          _status = UpdateCheckStatus.upToDate;
        }
        notifyListeners();
        return release;
      } else if (res.statusCode == 404) {
        // No releases published yet on repository
        _status = UpdateCheckStatus.upToDate;
        notifyListeners();
        return null;
      } else {
        throw Exception('GitHub API returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('AppUpdateService: Check update failed: $e');
      _status = UpdateCheckStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> downloadUpdate(AppReleaseInfo release) async {
    final asset = release.platformAsset();
    if (asset == null || asset.downloadUrl.isEmpty) {
      // Fallback: open release page in browser
      await openExternalUrl(release.htmlUrl);
      return null;
    }

    _status = UpdateCheckStatus.downloading;
    _downloadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
      targetDir ??= await getTemporaryDirectory();

      final fileName = asset.name.isNotEmpty ? asset.name : 'DraftFlow-Update.zip';
      final file = File('${targetDir.path}/$fileName');

      final request = http.Request('GET', Uri.parse(asset.downloadUrl));
      request.headers['User-Agent'] = 'DraftFlow-App-Updater';
      final response = await _client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength ?? asset.size;
        var receivedBytes = 0;
        final sink = file.openWrite();

        await response.stream.listen((chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _downloadProgress = receivedBytes / totalBytes;
            notifyListeners();
          }
        }).asFuture<void>();

        await sink.flush();
        await sink.close();

        _downloadedFilePath = file.path;
        _status = UpdateCheckStatus.downloaded;
        notifyListeners();
        return file.path;
      } else {
        throw Exception('Download failed with HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('AppUpdateService: Download error: $e');
      _status = UpdateCheckStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> openDownloadedFile() async {
    if (_downloadedFilePath == null) return;
    final path = _downloadedFilePath!;

    try {
      if (Platform.isMacOS) {
        // Reveal in Finder and open
        await Process.run('open', ['-R', path]);
      } else if (Platform.isWindows) {
        // Select in Windows Explorer
        await Process.run('explorer.exe', ['/select,', path]);
      } else if (Platform.isAndroid || Platform.isLinux) {
        await openExternalUrl(path);
      }
    } catch (e) {
      debugPrint('AppUpdateService: Reveal file error: $e');
      await openExternalUrl(path);
    }
  }

  Future<void> openReleasePage() async {
    final url = _latestRelease?.htmlUrl ??
        'https://github.com/$gitHubRepoOwner/$gitHubRepoName/releases';
    await openExternalUrl(url);
  }
}
