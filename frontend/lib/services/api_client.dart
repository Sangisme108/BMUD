import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'session_manager.dart';

class ApiClient {
  ApiClient({AuthService? authService})
      : _authService = authService ?? AuthService();

  static const _requestTimeout = Duration(seconds: 15);
  final AuthService _authService;

  Future<http.Response> get(String path) =>
      _authorizedRequest((headers) => http.get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: headers,
          ));

  Future<http.Response> delete(String path) =>
      _authorizedRequest((headers) => http.delete(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: headers,
          ));

  Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    if (!authenticated) {
      return _send(
        () => http.post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
      );
    }

    return _authorizedRequest(
      (headers) => http.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var response = await _send(() async => send(await _authHeaders()));

    if (response.statusCode != 401) {
      return response;
    }

    final firstError = _decodeSafe(response);
    final firstCode = firstError['errorCode']?.toString();
    if (firstCode == 'SESSION_REVOKED' ||
        firstCode == 'REFRESH_TOKEN_REVOKED') {
      await SessionManager.instance.handleSessionRevoked(
        message: firstError['message']?.toString() ??
            'Thiết bị này đã bị đăng xuất từ một thiết bị khác.',
      );
      throw ApiException(
        firstError['message']?.toString() ?? 'Phiên đăng nhập đã bị thu hồi',
        statusCode: 401,
        errorCode: firstCode,
      );
    }

    if (firstCode != 'ACCESS_TOKEN_EXPIRED' &&
        firstCode != 'INVALID_TOKEN' &&
        firstCode != null &&
        firstCode.isNotEmpty) {
      throw ApiException(
        firstError['message']?.toString() ?? 'Không thể xác thực yêu cầu',
        statusCode: 401,
        errorCode: firstCode,
      );
    }

    final refreshed = await _authService.refreshSession();
    if (!refreshed) {
      final refreshError = firstError;
      if (refreshError['errorCode']?.toString() == 'SESSION_REVOKED') {
        await SessionManager.instance.handleSessionRevoked();
      }
      throw ApiException(
        refreshError['message']?.toString() ?? 'Phiên đăng nhập đã hết hạn',
        statusCode: 401,
        errorCode: refreshError['errorCode']?.toString(),
      );
    }

    response = await _send(() async => send(await _authHeaders()));
    if (response.statusCode == 401) {
      final retryError = _decodeSafe(response);
      if (retryError['errorCode']?.toString() == 'SESSION_REVOKED' ||
          retryError['errorCode']?.toString() == 'REFRESH_TOKEN_REVOKED') {
        await SessionManager.instance.handleSessionRevoked(
          message: retryError['message']?.toString() ??
              'Thiết bị này đã bị đăng xuất từ một thiết bị khác.',
        );
      }
      throw ApiException(
        retryError['message']?.toString() ?? 'Không thể xác thực yêu cầu',
        statusCode: 401,
        errorCode: retryError['errorCode']?.toString(),
      );
    }
    return response;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on ApiException {
      rethrow;
    } on Exception catch (error) {
      throw ApiException('Không thể kết nối máy chủ: $error');
    }
  }

  Map<String, dynamic> _decodeSafe(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      return {'message': response.body};
    }
  }
}
