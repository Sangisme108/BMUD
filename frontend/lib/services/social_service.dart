import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/social_models.dart';
import 'auth_service.dart';
import 'device_identity_service.dart';
import 'session_manager.dart';

class SocialService {
  static const _requestTimeout = Duration(seconds: 15);
  final AuthService _authService = AuthService();
  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

  Future<List<FriendUser>> getConversations() async {
    final data = await _request('GET', '/social/conversations');
    return _list(
      data,
    ).map((item) => FriendUser.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<FriendUser>> getFriends() async {
    final data = await _request('GET', '/social/friends');
    return _list(
      data,
    ).map((item) => FriendUser.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<FriendRequest>> getFriendRequests() async {
    final data = await _request('GET', '/social/friend-requests');
    return _list(data)
        .map((item) => FriendRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final data = await _request('GET', '/social/users?query=$encoded');
    return _list(data)
        .map((item) => UserSearchResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendFriendRequest(int userId) async {
    await _request(
      'POST',
      '/social/friend-requests',
      body: {'user_id': userId},
    );
  }

  Future<void> respondToFriendRequest(int requestId, String action) async {
    await _request(
      'POST',
      '/social/friend-requests/$requestId/respond',
      body: {'action': action},
    );
  }

  Future<List<ChatMessage>> getMessages(int friendId) async {
    final data = await _request('GET', '/social/messages/$friendId');
    return _list(data)
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(int friendId, String content) async {
    final data = await _request(
      'POST',
      '/social/messages/$friendId',
      body: {'content': content},
    );
    return ChatMessage.fromJson(data['data'] as Map<String, dynamic>);
  }

  List<dynamic> _list(Map<String, dynamic> data) {
    return data['data'] as List<dynamic>? ?? [];
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
        } else {
          await SessionManager.instance.handleSessionRevoked(
            message: 'Phien dang nhap da het han, vui long dang nhap lai.',
          );
          throw ApiException(
            firstError['message']?.toString() ??
                'Phien dang nhap da het han',
            statusCode: 401,
            errorCode: errorCode,
          );
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
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      'X-Device-Fingerprint': fingerprint,
      if (token != null) 'Authorization': 'Bearer $token',
    };

    if (method == 'POST') {
      return http
          .post(uri, headers: headers, body: jsonEncode(body ?? {}))
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
