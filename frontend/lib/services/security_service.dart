import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/login_history.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SecurityService {
  final ApiClient _apiClient = ApiClient();

  Future<List<LoginHistory>> getLoginHistory() async {
    final response = await _apiClient.get('/security/login-history');
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
    final response = await _apiClient.get('/security/dashboard');
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không tải được dashboard',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final response = await _apiClient.get('/auth/devices');
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không tải được thiết bị',
        statusCode: response.statusCode,
      );
    }
    return (data['data'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSecurityEvents() async {
    final response = await _apiClient.get('/security/events');
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không tải được nhật ký bảo mật',
        statusCode: response.statusCode,
      );
    }
    return (data['data'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> revokeDevice(String sessionId) async {
    final response =
        await _apiClient.delete('/auth/devices/$sessionId');
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không thể gỡ thiết bị',
        statusCode: response.statusCode,
      );
    }
    return data;
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
