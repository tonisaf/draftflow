import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Configuration for DraftFlow's local MCP HTTP loopback server.
class McpConfig {
  final int port;
  final String token;

  const McpConfig({required this.port, required this.token});

  Uri get url =>
      Uri(scheme: 'http', host: '127.0.0.1', port: port, path: '/mcp');

  McpConfig withPort(int port) => McpConfig(port: port, token: token);

  static McpConfig? tryDecode(Object? json) {
    if (json is! Map) return null;
    final port = json['port'];
    final token = json['token'];
    if (port is! int || port < 0 || port > 65535) return null;
    if (token is! String || token.length < 32) return null;
    return McpConfig(port: port, token: token);
  }

  Map<String, Object?> toJson() => {'port': port, 'token': token};

  static String newToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

abstract interface class McpConfigStore {
  Future<McpConfig?> load();
  Future<void> save(McpConfig config);
  Future<void> delete();
}

class FileMcpConfigStore implements McpConfigStore {
  final String? path;

  FileMcpConfigStore({this.path});

  static String get _home =>
      (Platform.isWindows
          ? Platform.environment['USERPROFILE']
          : Platform.environment['HOME']) ??
      '.';

  File get _file => File(
    path ??
        '$_home${Platform.pathSeparator}.draftflow'
            '${Platform.pathSeparator}mcp.json',
  );

  @override
  Future<McpConfig?> load() async {
    try {
      final file = _file;
      if (file.existsSync()) {
        final content = await file.readAsString();
        return McpConfig.tryDecode(jsonDecode(content));
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> save(McpConfig config) async {
    final file = _file;
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(config.toJson()), flush: true);
  }

  @override
  Future<void> delete() async {
    try {
      final file = _file;
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
