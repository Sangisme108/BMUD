import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/message_recovery_service.dart';

class MessageRecoverySetupScreen extends StatefulWidget {
  const MessageRecoverySetupScreen({super.key});

  @override
  State<MessageRecoverySetupScreen> createState() =>
      _MessageRecoverySetupScreenState();
}

class _MessageRecoverySetupScreenState
    extends State<MessageRecoverySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageRecoveryService = MessageRecoveryService();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _confirmCodeController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureCode = true;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    _codeController.dispose();
    _confirmCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final message = await _messageRecoveryService.setup(
        currentPassword: _passwordController.text,
        recoveryCode: _codeController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _message = message);
      _codeController.clear();
      _confirmCodeController.clear();
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mã khôi phục tin nhắn')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.sms_outlined,
              size: 62,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tạo mã riêng để khôi phục quyền xem tin nhắn cũ trên thiết bị mới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    obscureText: _obscureCode,
                    decoration: InputDecoration(
                      labelText: 'Mã khôi phục tin nhắn',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscureCode = !_obscureCode);
                        },
                        icon: Icon(
                          _obscureCode
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nhập mã khôi phục';
                      }
                      if (value.trim().length < 6) {
                        return 'Mã phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmCodeController,
                    obscureText: _obscureCode,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mã khôi phục',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    validator: (value) => value != _codeController.text
                        ? 'Mã khôi phục không khớp'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Lưu mã khôi phục'),
                    ),
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
