import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../modules/core/url_utils.dart';

const String currentAppVersion = '1.0.8';
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
      for (final a in assets) {
        final name = a.name.toLowerCase();
        if ((name.contains('mac') || name.contains('darwin')) &&
            (name.endsWith('.zip') || name.endsWith('.dmg'))) {
          return a;
        }
      }
      return null;
    } else if (Platform.isWindows) {
      for (final a in assets) {
        final name = a.name.toLowerCase();
        if ((name.contains('win') || name.contains('windows')) &&
            (name.endsWith('.zip') || name.endsWith('.exe') || name.endsWith('.msix'))) {
          return a;
        }
      }
      return null;
    } else if (Platform.isAndroid) {
      for (final a in assets) {
        if (a.name.toLowerCase().endsWith('.apk')) {
          return a;
        }
      }
      return null;
    }

    return null;
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
  installing,
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

        try {
          await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (totalBytes > 0) {
              _downloadProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
              notifyListeners();
              if (receivedBytes >= totalBytes) {
                break;
              }
            }
          }
        } finally {
          await sink.flush();
          await sink.close();
        }

        _downloadProgress = 1.0;
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

  Future<void> downloadAndInstall(AppReleaseInfo release) async {
    final path = await downloadUpdate(release);
    if (path != null) {
      await installAndRestart(zipFilePath: path);
    }
  }

  Future<void> installAndRestart({String? zipFilePath}) async {
    final targetPath = zipFilePath ?? _downloadedFilePath;
    if (targetPath == null || !File(targetPath).existsSync()) {
      throw Exception('Файл обновления не найден');
    }

    _status = UpdateCheckStatus.installing;
    _errorMessage = null;
    notifyListeners();

    try {
      if (Platform.isMacOS) {
        await _installAndRestartMac(targetPath);
      } else if (Platform.isWindows) {
        await _installAndRestartWindows(targetPath);
      } else {
        await openDownloadedFile();
      }
    } catch (e) {
      debugPrint('AppUpdateService: Install error: $e');
      _status = UpdateCheckStatus.error;
      _errorMessage = 'Ошибка установки: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _installAndRestartMac(String zipPath) async {
    final tempDir = Directory.systemTemp.createTempSync('draftflow_update_');

    // 1. Unzip
    final unzipRes = await Process.run('unzip', ['-q', '-o', zipPath, '-d', tempDir.path]);
    if (unzipRes.exitCode != 0) {
      throw Exception('Не удалось распаковать архив обновления: ${unzipRes.stderr}');
    }

    // 2. Locate extracted DraftFlow.app
    FileSystemEntity? extractedApp;
    for (final entity in tempDir.listSync()) {
      if (entity.path.endsWith('.app')) {
        extractedApp = entity;
        break;
      }
    }
    if (extractedApp == null) {
      throw Exception('В архиве обновления не найден .app бандл');
    }

    // 3. Locate current running DraftFlow.app
    final resolvedExe = Platform.resolvedExecutable;
    final currentAppBundle = Directory(resolvedExe).parent.parent.parent.path;
    if (!currentAppBundle.endsWith('.app')) {
      // In dev mode or direct binary run, launch the extracted app
      await Process.start('open', [extractedApp.path], mode: ProcessStartMode.detached);
      exit(0);
    }

    // 4. Create update.sh
    final scriptFile = File('${tempDir.path}/update.sh');
    final currentPid = pid;
    final scriptContent = '''#!/bin/bash
PID=$currentPid
TARGET_APP="${currentAppBundle.replaceAll('"', r'\"')}"
NEW_APP="${extractedApp.path.replaceAll('"', r'\"')}"
TEMP_DIR="${tempDir.path.replaceAll('"', r'\"')}"

while kill -0 "\$PID" 2>/dev/null; do
  sleep 0.2
done

# Remove quarantine attribute so Gatekeeper allows the app
xattr -dr com.apple.quarantine "\$NEW_APP" 2>/dev/null || true

rm -rf "\$TARGET_APP"
cp -R "\$NEW_APP" "\$TARGET_APP"
open "\$TARGET_APP"
rm -rf "\$TEMP_DIR"
''';
    await scriptFile.writeAsString(scriptContent);
    await Process.run('chmod', ['+x', scriptFile.path]);

    // 5. Run detached script & exit
    await Process.start('/bin/bash', [scriptFile.path], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _installAndRestartWindows(String zipPath) async {
    final tempDir = Directory.systemTemp.createTempSync('draftflow_update_');
    final normalizedZip = zipPath.replaceAll('/', '\\');
    final normalizedTemp = tempDir.path.replaceAll('/', '\\');

    // 1. Extract zip via tar or PowerShell (hidden)
    var extractOk = false;
    try {
      final tarRes = await Process.run('tar', ['-xf', normalizedZip, '-C', normalizedTemp]);
      if (tarRes.exitCode == 0) {
        extractOk = true;
      }
    } catch (_) {}

    if (!extractOk) {
      final psRes = await Process.run('powershell.exe', [
        '-WindowStyle',
        'Hidden',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Expand-Archive -LiteralPath "$normalizedZip" -DestinationPath "$normalizedTemp" -Force',
      ]);
      if (psRes.exitCode != 0) {
        throw Exception('Не удалось распаковать архив обновления: ${psRes.stderr}');
      }
    }

    // 2. Identify current installation directory and executable
    final resolvedExe = File(Platform.resolvedExecutable);
    final installDir = resolvedExe.parent.path;

    // Check if files were extracted into a single nested subfolder or directly into tempDir
    Directory effectiveSourceDir = tempDir;
    try {
      final entities = tempDir.listSync();
      final dirs = entities.whereType<Directory>().toList();
      final exes = entities
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.exe'))
          .toList();
      if (exes.isEmpty && dirs.length == 1) {
        effectiveSourceDir = dirs.first;
      }
    } catch (_) {}

    // 3. Create a detached PowerShell updater script outside the source directory
    final currentPid = pid;
    final psScriptFile = File(
      '${Directory.systemTemp.path}\\draftflow_updater_$currentPid.ps1',
    );

    final escapedSourceDir = effectiveSourceDir.path.replaceAll('"', '`"');
    final escapedTargetDir = installDir.replaceAll('"', '`"');
    final escapedExePath = resolvedExe.path.replaceAll('"', '`"');
    final escapedTempRoot = tempDir.path.replaceAll('"', '`"');

    final psContent = '''
\$targetPid = $currentPid
\$sourceDir = "$escapedSourceDir"
\$targetDir = "$escapedTargetDir"
\$exePath = "$escapedExePath"
\$tempRoot = "$escapedTempRoot"

# 1. Wait for DraftFlow process to exit cleanly
try {
    \$proc = Get-Process -Id \$targetPid -ErrorAction SilentlyContinue
    if (\$proc) {
        \$null = \$proc.WaitForExit(10000)
    }
} catch {}

# Extra pause to ensure Windows file handles and DLLs are released
Start-Sleep -Milliseconds 800

# 2. In case process hasn't exited, forcefully terminate it
try {
    Stop-Process -Id \$targetPid -Force -ErrorAction SilentlyContinue
} catch {}

# 3. Replace old files with updated binaries
Copy-Item -Path "\$sourceDir\\*" -Destination "\$targetDir" -Recurse -Force

# 4. Launch updated DraftFlow.exe
Start-Process -FilePath "\$exePath"

# 5. Clean up temporary extract folder and script
Start-Sleep -Milliseconds 600
Remove-Item -Path "\$tempRoot" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "\$PSCommandPath" -Force -ErrorAction SilentlyContinue
''';

    await psScriptFile.writeAsString(psContent);

    // 4. Launch PowerShell with completely hidden window style & exit
    await Process.start(
      'powershell.exe',
      [
        '-WindowStyle',
        'Hidden',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        psScriptFile.path,
      ],
      mode: ProcessStartMode.detached,
    );
    exit(0);
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
