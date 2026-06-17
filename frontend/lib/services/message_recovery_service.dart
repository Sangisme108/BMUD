import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'device_identity_service.dart';
import 'session_manager.dart';

class MessageRecoveryStatus {
  final bool hasRecoveryCode;
  final bool messageRecoveryVerified;

  const MessageRecoveryStatus({
    required this.hasRecoveryCode,
    required this.messageRecoveryVerified,
  });

  factory MessageRecoveryStatus.fromJson(Map<String, dynamic> json) {
    return MessageRecoveryStatus(
      hasRecoveryCode: json['has_recovery_code'] == true,
      messageRecoveryVerified: json['message_recovery_verified'] == true,
    );
  }
}

class MessageRecoveryService {
  static const _requestTimeout = Duration(seconds: 15);
  final AuthService _authService = AuthService();
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

  Future<MessageRecoveryStatus> getStatus() async {
    final data = await _request('GET', '/message-recovery/status');
    return MessageRecoveryStatus.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<String> setup({
    required String currentPassword,
    required String recoveryCode,
  }) async {
    final data = await _request(
      'POST',
      '/message-recovery/setup',
      body: {
        'current_password': currentPassword,
        'recovery_code': recoveryCode,
      },
    );
    return data['message']?.toString() ?? 'Đã cập nhật mã khôi phục tin nhắn';
  }

  Future<String> verify(String recoveryCode) async {
    final data = await _request(
      'POST',
      '/message-recovery/verify',
      body: {'recovery_code': recoveryCode},
    );
    return data['message']?.toString() ?? 'Đã khôi phục quyền xem tin nhắn';
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      var response = await _send(method, path, body);
      if (response.statusCode == 401) {
        final firstError = _decode(response);
        final errorCode = firstError['errorCode']?.toString();
        if (errorCode == 'SESSION_REVOKED' ||
            errorCode == 'REFRESH_TOKEN_REVOKED') {
          await SessionManager.instance.handleSessionRevoked(
            message: firstError['message']?.toString() ??
                'Thiết bị này đã bị đăng xuất từ một thiết bị khác.',
          );
          throw ApiException(
            firstError['message']?.toString() ?? 'Phiên đăng nhập đã bị thu hồi',
            statusCode: 401,
            errorCode: errorCode,
          );
        }
        if (await _authService.refreshSession()) {
          response = await _send(method, path, body);
        }
      }

      final data = _decode(response);
      if (response.statusCode >= 400) {
        throw ApiException(
          data['message']?.toString() ?? 'Yêu cầu thất bại',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on ApiException {
      rethrow;
    } on Exception catch (error) {
      throw ApiException('Không thể kết nối máy chủ: $error');
    }
  }

  Future<http.Response> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final token = await _authService.getToken();
    final fingerprint = await _deviceIdentity.getDeviceFingerprint();
    final headers = {
      'Content-Type': 'application/json',
      'X-Device-Fingerprint': fingerprint,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final mergedBody = {
      ...?body,
      'device_fingerprint': fingerprint,
    };
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    if (method == 'POST') {
      return http
          .post(uri, headers: headers, body: jsonEncode(mergedBody))
          .timeout(_requestTimeout);
    }
    return http.get(uri, headers: headers).timeout(_requestTimeout);
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
