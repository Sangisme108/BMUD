import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class AccountActionScreen extends StatefulWidget {
  final String action;
  final String token;

  const AccountActionScreen({
    super.key,
    required this.action,
    required this.token,
  });

  @override
  State<AccountActionScreen> createState() => _AccountActionScreenState();
}

class _AccountActionScreenState extends State<AccountActionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _completed = false;
  String? _message;

  bool get _isReset => widget.action == 'reset-password';

  Future<void> _submit() async {
    if (_isReset && !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final message = _isReset
          ? await _authService.resetPassword(
              token: widget.token,
              newPassword: _passwordController.text,
            )
          : await _authService.unlockAccount(widget.token);
      if (mounted) {
        setState(() {
          _completed = true;
          _message = message;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isReset ? 'Đặt lại mật khẩu' : 'Mở khóa tài khoản';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_completed) ...[
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    _message ?? 'Thao tác thành công',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _backToLogin,
                    child: const Text('Quay lại đăng nhập'),
                  ),
                ] else ...[
                  Text(
                    _isReset
                        ? 'Nhập mật khẩu mới cho tài khoản của bạn.'
                        : 'Nhấn nút bên dưới để xác nhận mở khóa tài khoản.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_isReset) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu mới',
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'Mật khẩu phải có ít nhất 8 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Mật khẩu không khớp'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isReset ? 'Đổi mật khẩu' : 'Mở khóa'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
