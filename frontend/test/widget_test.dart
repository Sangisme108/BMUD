import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/screens/login_screen.dart';

void main() {
  testWidgets('Login screen smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Phát hiện đăng nhập bất thường'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
    expect(find.text('Device name'), findsNothing);
  });
}
