import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SecurityLoginApp());

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Phát hiện đăng nhập bất thường'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });
}
