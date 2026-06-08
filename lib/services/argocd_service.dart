import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/argocd_app.dart';
import 'auth_service.dart';

class ArgoCDException implements Exception {
  final String message;
  final int? statusCode;

  const ArgoCDException(this.message, {this.statusCode});

  @override
  String toString() => 'ArgoCDException($statusCode): $message';
}

class ArgoCDService {
  final AuthService _authService;
  static const Duration _timeout = Duration(seconds: 30);

  ArgoCDService(this._authService);

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getValidIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? params]) {
    final base = Uri.parse('${AuthService.baseUrl}/api/v1$path');
    if (params != null && params.isNotEmpty) {
      return base.replace(queryParameters: params);
    }
    return base;
  }

  Future<dynamic> _get(String path, [Map<String, String>? params]) async {
    final headers = await _headers();
    try {
      final response = await http
          .get(_uri(path, params), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw const ArgoCDException('Request timed out');
    } on http.ClientException catch (e) {
      throw ArgoCDException('Network error: ${e.message}');
    }
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final headers = await _headers();
    try {
      final response = await http
          .post(
            _uri(path),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw const ArgoCDException('Request timed out');
    } on http.ClientException catch (e) {
      throw ArgoCDException('Network error: ${e.message}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw const ArgoCDException('Session expired. Please log in again.',
          statusCode: 401);
    }
    if (response.statusCode == 403) {
      throw const ArgoCDException('Permission denied.', statusCode: 403);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String errorMsg = 'Request failed (${response.statusCode})';
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      errorMsg = json['message'] as String? ?? errorMsg;
    } catch (_) {}
    throw ArgoCDException(errorMsg, statusCode: response.statusCode);
  }

  /// Cheap authenticated probe used by the splash router to verify the
  /// stored token is still accepted by the server. Returns true on 2xx,
  /// false only on 401. Network / timeout / other errors propagate so the
  /// caller can keep the user on the app screen instead of kicking them
  /// to login just because they're offline.
  Future<bool> validateSession() async {
    try {
      await _get('/session/userinfo');
      return true;
    } on ArgoCDException catch (e) {
      if (e.statusCode == 401) return false;
      rethrow;
    }
  }

  /// List all applications
  Future<List<ArgoApp>> listApplications() async {
    final data = await _get('/applications');
    final items = (data['items'] as List<dynamic>?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => ArgoApp.fromJson(j))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Get single application details (raw JSON for resource tree etc.)
  Future<Map<String, dynamic>> getApplication(String name) async {
    final data = await _get('/applications/$name');
    return data as Map<String, dynamic>;
  }

  /// Get resource tree
  Future<List<ResourceNode>> getResourceTree(String appName) async {
    try {
      final data = await _get('/applications/$appName/resource-tree');
      final nodes = (data['nodes'] as List<dynamic>?) ?? [];
      return nodes
          .whereType<Map<String, dynamic>>()
          .map((j) => ResourceNode.fromJson(j))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Trigger sync
  Future<void> syncApplication(String name) async {
    await _post('/applications/$name/sync', {
      'name': name,
      'prune': false,
      'dryRun': false,
      'strategy': {
        'apply': {'force': false}
      },
    });
  }

  /// Trigger hard refresh
  Future<ArgoApp> refreshApplication(String name) async {
    final data =
        await _get('/applications/$name', {'refresh': 'hard'});
    return ArgoApp.fromJson(data as Map<String, dynamic>);
  }

  /// Stream logs — returns lines as a Stream
  /// ArgoCD logs endpoint returns newline-delimited JSON objects
  Stream<String> streamLogs({
    required String appName,
    String? namespace,
    String? podName,
    String? container,
    int tailLines = 200,
  }) async* {
    final token = await _authService.getValidIdToken();
    final params = <String, String>{
      'tailLines': tailLines.toString(),
      'follow': 'false',
    };
    if (namespace != null) params['namespace'] = namespace;
    if (podName != null) params['podName'] = podName;
    if (container != null) params['container'] = container;

    final uri = _uri('/applications/$appName/logs', params);
    final request = http.Request('GET', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final streamedResponse = await http.Client().send(request).timeout(_timeout);
      if (streamedResponse.statusCode == 401) {
        yield '[Error] Session expired';
        return;
      }
      if (streamedResponse.statusCode != 200) {
        yield '[Error] Failed to fetch logs (${streamedResponse.statusCode})';
        return;
      }

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final obj = jsonDecode(trimmed) as Map<String, dynamic>;
            // ArgoCD wraps each line: {"result": {"content": "...", ...}}
            final result = obj['result'] as Map<String, dynamic>?;
            final content = result?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {
            // Not JSON — yield raw
            if (trimmed.isNotEmpty) yield trimmed;
          }
        }
      }
    } on TimeoutException {
      yield '[Error] Log stream timed out';
    } on Exception catch (e) {
      yield '[Error] $e';
    }
  }
}
