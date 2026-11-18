import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:notes_here/mcp/draftflow_db_client.dart';
import 'package:notes_here/mcp/draftflow_mcp_server.dart';
import 'package:notes_here/mcp/mcp_config.dart';

void main(List<String> args) async {
  String? dbPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _printHelp();
      exit(0);
    } else if (arg == '--detect') {
      final detected = DraftFlowDbClient.findDatabasePath();
      if (detected != null) {
        stdout.writeln('DraftFlow database detected at: $detected');
        exit(0);
      } else {
        stderr.writeln('No DraftFlow database found in standard locations.');
        exit(1);
      }
    } else if (arg == '--test') {
      final path = DraftFlowDbClient.findDatabasePath();
      if (path == null) {
        stderr.writeln('Error: DraftFlow database not found.');
        exit(1);
      }
      try {
        final client = DraftFlowDbClient.open(path);
        final pages = client.listPages();
        final dbs = client.listDatabases();
        stdout.writeln('DraftFlow MCP Self-Test: SUCCESS');
        stdout.writeln('Database: $path');
        stdout.writeln('Pages: ${pages.length}');
        stdout.writeln('Databases: ${dbs.length}');
        client.close();
        exit(0);
      } catch (e) {
        stderr.writeln('DraftFlow MCP Self-Test: FAILED ($e)');
        exit(1);
      }
    } else if (arg == '--db-path' || arg == '-d') {
      if (i + 1 < args.length) {
        dbPath = args[++i];
      }
    } else if (arg.startsWith('--db-path=')) {
      dbPath = arg.substring('--db-path='.length);
    }
  }

  // Hybrid Bridge Routing:
  // 1. If DraftFlow GUI is running, forward requests over loopback HTTP
  final store = FileMcpConfigStore();
  final config = await store.load();

  if (config != null && config.port > 0) {
    final isAlive = await _checkGuiAlive(config);
    if (isAlive) {
      await _runHttpBridge(config, dbPath: dbPath);
      return;
    }
  }

  // 2. Headless offline fallback mode (directly against SQLite)
  try {
    final server = await DraftFlowMcpServer.create(dbPath);
    await server.start();
  } catch (e) {
    stderr.writeln('DraftFlow MCP Server Error: $e');
    exit(1);
  }
}

Future<bool> _checkGuiAlive(McpConfig config) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 300);
    final req = await client.postUrl(config.url);
    req.headers
      ..set('Host', '127.0.0.1:${config.port}')
      ..set('Authorization', 'Bearer ${config.token}')
      ..contentType = ContentType.json;
    req.write(jsonEncode({'jsonrpc': '2.0', 'id': 0, 'method': 'ping'}));
    final resp = await req.close();
    client.close(force: true);
    return resp.statusCode == HttpStatus.ok;
  } catch (_) {
    return false;
  }
}

Future<void> _runHttpBridge(McpConfig config, {String? dbPath}) async {
  final client = HttpClient();
  DraftFlowMcpServer? fallbackServer;

  final lines = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    var forwarded = false;
    try {
      final req = await client.postUrl(config.url);
      req.headers
        ..set('Host', '127.0.0.1:${config.port}')
        ..set('Authorization', 'Bearer ${config.token}')
        ..contentType = ContentType.json;
      req.write(trimmed);
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        final body = await utf8.decoder.bind(resp).join();
        stdout.writeln(body.trim());
        forwarded = true;
      } else if (resp.statusCode == HttpStatus.accepted) {
        forwarded = true;
      }
    } on SocketException {
      // GUI stopped, fall back to headless
    } catch (_) {}

    if (!forwarded) {
      // Fallback to local headless processing if GUI is unreachable
      fallbackServer ??= await DraftFlowMcpServer.create(dbPath);
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        final reply = await fallbackServer.handleMessage(decoded);
        if (reply != null) {
          stdout.writeln(jsonEncode(reply));
        }
      } catch (e) {
        stdout.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': null,
          'error': {'code': -32700, 'message': 'Parse error: $e'},
        }));
      }
    }
  }

  client.close(force: true);
}

void _printHelp() {
  stdout.writeln('''
DraftFlow Hybrid MCP Server (Model Context Protocol)
Connects external AI agents (Antigravity, Claude Code, Codex, Cursor) directly to your DraftFlow notes and relational databases.

Usage:
  dart run bin/draftflow_mcp.dart [options]

Modes:
  - Online (GUI running): Transparently forwards requests to local HTTP server for real-time Drift UI reactivity and instant Supabase sync.
  - Offline (GUI closed): Automatically falls back to direct SQLite access (WAL mode) for 24/7 autonomous agent access.

Options:
  -d, --db-path <path>  Explicit path to DraftFlow SQLite database (.sqlite)
  --detect              Detect and print the local DraftFlow database path
  --test                Run self-test on the detected database
  -h, --help            Show this help message
''');
}
