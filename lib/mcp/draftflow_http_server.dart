import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'draftflow_mcp_server.dart';
import 'mcp_config.dart';

/// Lightweight loopback HTTP server (`POST /mcp`) that runs inside DraftFlow GUI.
///
/// Enables external AI agents to interact with the running DraftFlow application:
/// - Instant UI reactivity via Drift streams.
/// - Immediate Supabase sync.
class DraftFlowHttpServer extends ChangeNotifier {
  final DraftFlowMcpServer mcpServer;
  final McpConfigStore store;

  HttpServer? _server;
  McpConfig? _config;
  String? _error;

  DraftFlowHttpServer({
    required this.mcpServer,
    McpConfigStore? store,
  }) : store = store ?? FileMcpConfigStore();

  bool get isRunning => _server != null;
  McpConfig? get config => _config;
  String? get error => _error;

  Future<void> start() async {
    if (_server != null) return;
    _error = null;

    var config = await store.load() ??
        McpConfig(port: 0, token: McpConfig.newToken());

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, config.port);
    } on SocketException {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      } on SocketException catch (e) {
        _error = e.message;
        notifyListeners();
        return;
      }
    }

    if (server != null) {
      config = config.withPort(server.port);
      try {
        await store.save(config);
      } catch (e) {
        _error = 'Failed to save mcp.json: $e';
      }
      _server = server;
      _config = config;
      unawaited(_listen(server, config));
    }

    notifyListeners();
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
    notifyListeners();
  }

  Future<void> _listen(HttpServer server, McpConfig config) async {
    await for (final request in server) {
      unawaited(_handleRequest(request, config));
    }
  }

  Future<void> _handleRequest(HttpRequest request, McpConfig config) async {
    final response = request.response;
    try {
      // Security: Disallow cross-origin browser requests (CSRF)
      if (request.headers.value('origin') != null) {
        return _sendError(response, HttpStatus.forbidden, 'Origin not allowed');
      }

      // Security: Validate loopback Host to prevent DNS rebinding
      final host = request.headers.value('host')?.toLowerCase();
      final port = config.port;
      if (host != '127.0.0.1:$port' &&
          host != 'localhost:$port' &&
          host != '[::1]:$port') {
        return _sendError(response, HttpStatus.forbidden, 'Host not allowed');
      }

      // Security: Validate Bearer token authentication
      final auth = request.headers.value('authorization');
      if (auth == null || auth != 'Bearer ${config.token}') {
        response.headers.set('WWW-Authenticate', 'Bearer');
        return _sendError(response, HttpStatus.unauthorized, 'Unauthorized');
      }

      if (request.uri.path != '/mcp') {
        return _sendError(response, HttpStatus.notFound, 'Not found');
      }

      if (request.method != 'POST') {
        response.headers.set('Allow', 'POST');
        return _sendError(
          response,
          HttpStatus.methodNotAllowed,
          'Method not allowed',
        );
      }

      final bodyBytes = await request.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      final bodyString = utf8.decode(bodyBytes);

      final Map<String, dynamic> message;
      try {
        message = jsonDecode(bodyString) as Map<String, dynamic>;
      } catch (e) {
        return _sendJson(response, HttpStatus.badRequest, {
          'jsonrpc': '2.0',
          'id': null,
          'error': {'code': -32700, 'message': 'Parse error: $e'},
        });
      }

      final reply = await mcpServer.handleMessage(message);
      if (reply == null) {
        response.statusCode = HttpStatus.accepted;
        return;
      }

      _sendJson(response, HttpStatus.ok, reply);
    } catch (e) {
      try {
        _sendError(
          response,
          HttpStatus.internalServerError,
          'Internal server error: $e',
        );
      } catch (_) {}
    } finally {
      unawaited(response.close().catchError((_) {}));
    }
  }

  void _sendError(HttpResponse response, int status, String msg) {
    response.statusCode = status;
    response.headers.contentType = ContentType.text;
    response.write(msg);
  }

  void _sendJson(
    HttpResponse response,
    int status,
    Map<String, dynamic> json,
  ) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(json));
  }
}
