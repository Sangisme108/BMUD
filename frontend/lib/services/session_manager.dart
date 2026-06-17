import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'auth_service.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final AuthService _authService = AuthService();
  bool _handlingRevokedSession = false;

  Future<void> handleSessionRevoked({
    String message =
        'Thiết bị này đã bị đăng xuất từ một thiết bị khác.',
  }) async {
    if (_handlingRevokedSession) return;
    _handlingRevokedSession = true;
    try {
      await _authService.clearSession(keepDeviceId: true);
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(initialMessage: message),
        ),
        (_) => false,
      );
    } finally {
      _handlingRevokedSession = false;
    }
  }
}
