import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/login_history.dart';
import 'auth_service.dart';

class SecurityService {
  static const _requestTimeout = Duration(seconds: 15);
  final AuthService _authService = AuthService();

  Future<List<LoginHistory>> getLoginHistory() async {
    final response = await _authorizedGet('/security/login-history');
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không tải được lịch sử đăng nhập',
        statusCode: response.statusCode,
      );
    }

    final items = data['data'] as List<dynamic>;
    return items
        .map((item) => LoginHistory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _authorizedGet('/security/dashboard');
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không tải được dashboard',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<http.Response> _authorizedGet(String path) async {
    try {
      var response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: await _headers(),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 401 && await _authService.refreshSession()) {
        response = await http
            .get(
              Uri.parse('${ApiConfig.baseUrl}$path'),
              headers: await _headers(),
            )
            .timeout(_requestTimeout);
      }
      return response;
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on ApiException {
      rethrow;
    } on Exception catch (error) {
      throw ApiException('Không thể kết nối máy chủ: $error');
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        'Phản hồi từ máy chủ không hợp lệ',
        statusCode: response.statusCode,
      );
    }
  }
}
