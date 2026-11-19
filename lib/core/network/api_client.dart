import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final String? correlationId;

  ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.correlationId,
  });

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class ApiClient {
  // Android Emulator usa 10.0.2.2 para acceder al localhost del equipo.
  // Web, iOS y escritorio utilizan localhost.
  static String get defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  static String? _globalAuthToken;

  static void setGlobalAuthToken(String? token) {
    _globalAuthToken = token;
  }

  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  ApiClient({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  void setAuthToken(String? token) {
    _authToken = token;
    _globalAuthToken = token;
  }

  Map<String, String> _buildHeaders([Map<String, String>? extraHeaders]) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // ID de correlación para facilitar la trazabilidad de cada petición.
      'X-Correlation-ID': 'corr-${DateTime.now().millisecondsSinceEpoch}',
    };

    final token = _authToken ?? _globalAuthToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await _client.get(
        uri,
        headers: _buildHeaders(),
      );
      return _processResponse(response);
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'No hay conexión con el servidor de BankOS. Verifica tu red o el contenedor.',
      );
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body, {String? idempotencyKey}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = _buildHeaders();
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Error de conexión con el servidor bancario.',
      );
    }
  }

  Future<dynamic> patch(String endpoint, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await _client.patch(
        uri,
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } on http.ClientException {
      throw ApiException(
        statusCode: 0,
        message: 'Error de conexión al actualizar recurso.',
      );
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String errorMessage = 'Error inesperado del servidor';
    String? errorCode;
    String? correlationId;

    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('detail')) {
        errorMessage = decoded['detail'].toString();
      } else if (decoded.containsKey('error')) {
        final errObj = decoded['error'];
        if (errObj is Map<String, dynamic>) {
          errorMessage = errObj['message']?.toString() ?? errorMessage;
          errorCode = errObj['code']?.toString();
          correlationId = errObj['correlation_id']?.toString();
        }
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      code: errorCode,
      correlationId: correlationId,
    );
  }
}
