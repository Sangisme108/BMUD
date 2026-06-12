import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

enum RecoveryRequestType { resetPassword, unlockAccount }

class AccountRecoveryRequestScreen extends StatefulWidget {
  final RecoveryRequestType type;
  final String initialEmail;

  const AccountRecoveryRequestScreen({
    super.key,
    required this.type,
    this.initialEmail = '',
  });

  @override
  State<AccountRecoveryRequestScreen> createState() =>
      _AccountRecoveryRequestScreenState();
}

class _AccountRecoveryRequestScreenState
    extends State<AccountRecoveryRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _message;

  bool get _isReset => widget.type == RecoveryRequestType.resetPassword;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final email = _emailController.text.trim();
      final message = _isReset
          ? await _authService.requestPasswordReset(email)
          : await _authService.requestUnlock(email);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _message = message;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final email = _emailController.text.trim();
      final otpCode = _otpController.text.trim();
      final message = _isReset
          ? await _authService.resetPassword(
              email: email,
              otpCode: otpCode,
              newPassword: _passwordController.text,
            )
          : await _authService.unlockAccount(email: email, otpCode: otpCode);
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
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isReset ? 'Quên mật khẩu' : 'Mở khóa tài khoản';
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
                    _otpSent
                        ? 'Nhập mã OTP 6 số đã gửi qua email.'
                        : _isReset
                        ? 'Nhập email để nhận OTP đặt lại mật khẩu.'
                        : 'Nhập email để nhận OTP mở khóa tài khoản.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    readOnly: _otpSent,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Nhập email';
                      if (!email.contains('@')) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otpController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Mã OTP'),
                      validator: (value) => value?.length == 6
                          ? null
                          : 'OTP phải gồm đúng 6 chữ số',
                    ),
                    if (_isReset) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            tooltip: _obscurePassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                          ),
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
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            tooltip: _obscureConfirmPassword
                                ? 'Hiện mật khẩu'
                                : 'Ẩn mật khẩu',
                          ),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Mật khẩu không khớp'
                            : null,
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : _otpSent
                        ? _verifyOtp
                        : _sendOtp,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_otpSent ? 'Xác nhận OTP' : 'Gửi OTP'),
                  ),
                  if (_otpSent)
                    TextButton(
                      onPressed: _loading ? null : _sendOtp,
                      child: const Text('Gửi lại OTP'),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!, textAlign: TextAlign.center),
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
