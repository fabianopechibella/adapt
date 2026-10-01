import 'dart:convert';

import 'package:http/http.dart' as http;

import '../repositories.dart';

/// Cliente REST do BFF de cada canal. Traduz erros para [AppException].
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenProvider, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUrl;
  final String? Function() tokenProvider;
  final http.Client _client;

  static const timeout = Duration(seconds: 15);

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body, headers: headers);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = baseUrl.replace(
      path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
        if (tokenProvider() case final token?) 'Authorization': 'Bearer $token',
        ...?headers,
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on Exception {
      throw const AppException('Sem conexão com o servidor. Tente de novo.', code: 'network');
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final error = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    throw AppException(
      error['message'] as String? ?? 'Erro inesperado (${response.statusCode}).',
      code: error['code'] as String? ?? 'http_${response.statusCode}',
    );
  }

  void close() => _client.close();
}
