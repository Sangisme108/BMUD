import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/device_service.dart';
import 'account_recovery_request_screen.dart';
import 'home_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _deviceService = DeviceService();

  bool _loading = false;
  String? _message;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final fingerprint = await _deviceService.getDeviceFingerprint();
      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        deviceFingerprint: fingerprint,
      );

      if (!mounted) return;
      if (result.requiresOtp) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: _emailController.text.trim(),
              deviceFingerprint: fingerprint,
              debugOtp: result.data['debug_otp']?.toString(),
            ),
          ),
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(userJson: result.data['user']),
        ),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không thể đọc thông tin thiết bị: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Phát hiện đăng nhập bất thường',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thiết bị được nhận diện tự động và không hiển thị trên giao diện.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Nhập email';
                      if (!email.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Nhập mật khẩu' : null,
                    onFieldSubmitted: (_) {
                      if (!_loading) _login();
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đăng nhập'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountRecoveryRequestScreen(
                                  type: RecoveryRequestType.resetPassword,
                                  initialEmail: _emailController.text.trim(),
                                ),
                              ),
                            );
                          },
                    child: const Text('Quên mật khẩu?'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountRecoveryRequestScreen(
                                  type: RecoveryRequestType.unlockAccount,
                                  initialEmail: _emailController.text.trim(),
                                ),
                              ),
                            );
                          },
                    child: const Text('Tài khoản bị khóa?'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text('Chưa có tài khoản? Đăng ký'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
