import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user.dart';
import 'device_identity_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const ApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() => message;
}

class LoginResult {
  final int statusCode;
  final Map<String, dynamic> data;

  const LoginResult({required this.statusCode, required this.data});

  bool get requiresOtp =>
      statusCode == 202 ||
      data['requiresOtp'] == true ||
      data['requires_otp'] == true;
}

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _requestTimeout = Duration(seconds: 15);
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Đăng ký thất bại',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<int> sendRegisterOtp({
    required String fullName,
    required String email,
  }) async {
    final response = await _post('/auth/register/send-otp', {
      'fullName': fullName,
      'email': email,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Khong the gui OTP dang ky',
        statusCode: response.statusCode,
      );
    }
    return int.tryParse(data['expiresIn']?.toString() ?? '') ?? 300;
  }

  Future<Map<String, dynamic>> verifyRegisterOtp({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
    required String otp,
  }) async {
    final device = await _deviceIdentity.getDevicePayload();
    final response = await _post('/auth/register/verify-otp', {
      'fullName': fullName,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
      'otp': otp,
      ...device,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Xac minh OTP dang ky that bai',
        statusCode: response.statusCode,
      );
    }
    if (data['access_token'] == null ||
        data['refresh_token'] == null ||
        data['user'] == null) {
      throw const ApiException('May chu khong tra ve phien dang nhap hop le');
    }
    await _saveSession(data);
    return data;
  }

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final device = await _deviceIdentity.getDevicePayload();
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
      ...device,
    });
    final data = _decode(response);

    if (response.statusCode == 200) {
      await _saveSession(data);
      return LoginResult(statusCode: response.statusCode, data: data);
    }
    if (response.statusCode == 202) {
      return LoginResult(statusCode: response.statusCode, data: data);
    }

    throw ApiException(
      data['message']?.toString() ?? _messageForStatus(response.statusCode),
      statusCode: response.statusCode,
      errorCode: data['errorCode']?.toString(),
    );
  }

  Future<Map<String, dynamic>> verifyDeviceOtp({
    required String challengeId,
    required String otpCode,
  }) async {
    final device = await _deviceIdentity.getDevicePayload();
    final response = await _post('/auth/login/verify-device-otp', {
      'challengeId': challengeId,
      'otp': otpCode,
      ...device,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Xác thực OTP thất bại',
        statusCode: response.statusCode,
      );
    }

    await _saveSession(data);
    return data;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    final device = await _deviceIdentity.getDevicePayload();
    final response = await _post('/auth/verify-otp', {
      'email': email,
      'otp_code': otpCode,
      ...device,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Xác thực OTP thất bại',
        statusCode: response.statusCode,
      );
    }

    await _saveSession(data);
    return data;
  }

  Future<String> requestPasswordReset(String email) async {
    return _requestAccountAction('/auth/forgot-password', email);
  }

  Future<String> requestUnlock(String email) async {
    return _requestAccountAction('/auth/request-unlock', email);
  }

  Future<String> unlockAccount({
    required String email,
    required String otpCode,
  }) async {
    final response = await _post('/auth/unlock-account', {
      'email': email,
      'otp_code': otpCode,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không thể mở khóa tài khoản',
        statusCode: response.statusCode,
      );
    }
    return data['message']?.toString() ?? 'Tài khoản đã được mở khóa';
  }

  Future<String> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    final response = await _post('/auth/reset-password', {
      'email': email,
      'otp_code': otpCode,
      'new_password': newPassword,
    });
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không thể đặt lại mật khẩu',
        statusCode: response.statusCode,
      );
    }
    await logout();
    return data['message']?.toString() ?? 'Mật khẩu đã được thay đổi';
  }

  Future<User?> getSavedUser() async {
    final rawUser = await _storage.read(key: 'user');
    if (rawUser == null) return null;
    return User.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
  }

  Future<String?> getToken() => _storage.read(key: 'access_token');

  Future<String?> getSessionId() => _storage.read(key: 'session_id');

  Future<bool> refreshSession() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;

    try {
      final device = await _deviceIdentity.getDevicePayload();
      final response = await _post('/auth/refresh', {
        'refresh_token': refreshToken,
        ...device,
      });
      final data = _decode(response);
      if (response.statusCode != 200) {
        final errorCode = data['errorCode']?.toString();
        if (errorCode == 'SESSION_REVOKED' ||
            errorCode == 'REFRESH_TOKEN_REVOKED') {
          await clearSession(keepDeviceId: true);
        } else {
          await clearSession(keepDeviceId: true);
        }
        return false;
      }

      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;

      await _storage.write(
        key: 'access_token',
        value: payload['access_token']?.toString(),
      );
      await _storage.write(
        key: 'refresh_token',
        value: payload['refresh_token']?.toString(),
      );
      await _storage.write(
        key: 'session_id',
        value: payload['session_id']?.toString(),
      );
      return true;
    } on ApiException {
      await clearSession(keepDeviceId: true);
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      try {
        final device = await _deviceIdentity.getDevicePayload();
        await _post('/auth/logout', {
          'refresh_token': refreshToken,
          ...device,
        });
      } on ApiException {
        // Local logout must still succeed when the backend is unavailable.
      }
    }
    await clearSession(keepDeviceId: true);
  }

  Future<void> clearSession({required bool keepDeviceId}) async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'session_id');
    await _storage.delete(key: 'user');
    if (!keepDeviceId) {
      await _storage.delete(key: 'device_id');
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _storage.write(
      key: 'access_token',
      value: data['access_token']?.toString(),
    );
    await _storage.write(
      key: 'refresh_token',
      value: data['refresh_token']?.toString(),
    );
    await _storage.write(
      key: 'session_id',
      value: data['session_id']?.toString(),
    );
    await _storage.write(key: 'user', value: jsonEncode(data['user']));
  }

  Future<String> _requestAccountAction(String path, String email) async {
    final response = await _post(path, {'email': email});
    final data = _decode(response);
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? 'Không thể gửi email hướng dẫn',
        statusCode: response.statusCode,
      );
    }
    return data['message']?.toString() ?? 'Hãy kiểm tra hộp thư của bạn';
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on Exception catch (error) {
      throw ApiException('Không thể kết nối máy chủ: $error');
    }
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

  String _messageForStatus(int statusCode) {
    return switch (statusCode) {
      401 => 'Email hoặc mật khẩu không chính xác',
      403 => 'Phiên đăng nhập bị chặn do rủi ro cao',
      423 => 'Tài khoản đang bị khóa tạm thời',
      _ => 'Đăng nhập thất bại',
    };
  }
}
