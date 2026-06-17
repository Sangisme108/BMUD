import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();

  Timer? _resendTimer;
  bool _loading = false;
  bool _verifying = false;
  bool _otpSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendSeconds = 0;
  String? _message;

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await _authService.sendRegisterOtp(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpController.clear();
      });
      _startResendCountdown();
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _loading) return;
    await _sendOtp();
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate() || _verifying) return;

    setState(() {
      _verifying = true;
      _message = null;
    });

    try {
      final data = await _authService.verifyRegisterOtp(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmController.text,
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userJson: data['user'])),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  void _backToEditEmail() {
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _resendSeconds = 0;
      _message = null;
      _otpController.clear();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(_otpSent ? 'Xác minh email' : 'Đăng ký')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _otpSent ? _buildOtpStep() : _buildRegisterStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('register-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tạo tài khoản',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Xác minh Gmail bằng OTP trước khi tạo tài khoản.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Nhập họ tên' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
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
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Nhập mật khẩu';
              if (value.length < 8) return 'Mật khẩu ít nhất 8 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Xác nhận mật khẩu',
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _sendOtp,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Đăng ký'),
          ),
          _buildMessage(),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final email = _emailController.text.trim();
    return Form(
      key: _otpFormKey,
      child: Column(
        key: const ValueKey('otp-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 58),
          const SizedBox(height: 14),
          const Text(
            'Xác minh email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Mã OTP gồm 6 chữ số đã được gửi đến email $email',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Mã OTP',
              counterText: '',
            ),
            validator: (value) =>
                value?.length == 6 ? null : 'OTP phải gồm đúng 6 chữ số',
            onFieldSubmitted: (_) {
              if (!_verifying) _verifyOtp();
            },
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _verifying ? null : _verifyOtp,
            child: _verifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Xác nhận OTP'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: (_loading || _resendSeconds > 0) ? null : _resendOtp,
            child: Text(
              _resendSeconds > 0
                  ? 'Gửi lại mã sau $_resendSeconds giây'
                  : 'Gửi lại mã',
            ),
          ),
          TextButton(
            onPressed: _verifying || _loading ? null : _backToEditEmail,
            child: const Text('Quay lại chỉnh sửa email'),
          ),
          _buildMessage(),
        ],
      ),
    );
  }

  Widget _buildMessage() {
    if (_message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _message!,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
