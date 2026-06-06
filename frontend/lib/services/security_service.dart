import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/login_history.dart';
import 'auth_service.dart';

class SecurityService {
  final AuthService _authService = AuthService();

  Future<List<LoginHistory>> getLoginHistory() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/security/login-history'),
      headers: await _headers(),
    );

    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Không tải được lịch sử đăng nhập');
    }

    final items = data['data'] as List<dynamic>;
    return items
        .map((item) => LoginHistory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/security/dashboard'),
      headers: await _headers(),
    );

    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Không tải được dashboard');
    }
    return data;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
