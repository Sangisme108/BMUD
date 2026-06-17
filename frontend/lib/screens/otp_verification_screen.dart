import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const _enableDebugOtp = bool.fromEnvironment(
    'ENABLE_DEBUG_OTP',
    defaultValue: false,
  );

  final String email;
  final String deviceFingerprint;
  final String? debugOtp;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.deviceFingerprint,
    this.debugOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (OtpVerificationScreen._enableDebugOtp && widget.debugOtp != null) {
      _otpController.text = widget.debugOtp!;
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await _authService.verifyOtp(
        email: widget.email,
        otpCode: _otpController.text.trim(),
        deviceFingerprint: widget.deviceFingerprint,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userJson: result['user'])),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực thiết bị')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nhập mã OTP gồm 6 chữ số đã gửi đến ${widget.email}.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (OtpVerificationScreen._enableDebugOtp &&
                    widget.debugOtp != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Chế độ phát triển: OTP ${widget.debugOtp}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _otpController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Mã OTP'),
                  validator: (value) =>
                      value?.length == 6 ? null : 'OTP phải gồm đúng 6 chữ số',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác thực'),
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
    );
  }
}
