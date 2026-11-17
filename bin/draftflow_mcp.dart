import 'dart:io';

import 'package:notes_here/mcp/draftflow_db_client.dart';
import 'package:notes_here/mcp/draftflow_mcp_server.dart';

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

  try {
    final server = await DraftFlowMcpServer.create(dbPath);
    await server.start();
  } catch (e) {
    stderr.writeln('DraftFlow MCP Server Error: $e');
    exit(1);
  }
}

void _printHelp() {
  stdout.writeln('''
DraftFlow MCP Server (Model Context Protocol)
Connects external AI agents (Antigravity, Claude Code, Codex, Cursor) directly to your DraftFlow notes and relational databases.

Usage:
  dart run bin/draftflow_mcp.dart [options]

Options:
  -d, --db-path <path>  Explicit path to DraftFlow SQLite database (.sqlite)
  --detect              Detect and print the local DraftFlow database path
  --test                Run self-test on the detected database
  -h, --help            Show this help message

Setup with Claude Code:
  claude mcp add draftflow dart run ${Directory.current.path}/bin/draftflow_mcp.dart

Setup with Antigravity:
  Add to ~/.gemini/antigravity/mcp_servers.json:
  {
    "mcpServers": {
      "draftflow": {
        "command": "dart",
        "args": ["run", "${Directory.current.path}/bin/draftflow_mcp.dart"]
      }
    }
  }

Setup with Codex / Cursor:
  Add to ~/.cursor/mcp.json:
  {
    "mcpServers": {
      "draftflow": {
        "command": "dart",
        "args": ["run", "${Directory.current.path}/bin/draftflow_mcp.dart"]
      }
    }
  }
''');
}
