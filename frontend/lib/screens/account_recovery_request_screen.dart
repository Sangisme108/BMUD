import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'account_action_screen.dart';

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

  bool _loading = false;
  String? _message;
  bool _success = false;

  bool get _isReset => widget.type == RecoveryRequestType.resetPassword;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
      _success = false;
    });

    try {
      final email = _emailController.text.trim();
      final message = _isReset
          ? await _authService.requestPasswordReset(email)
          : await _authService.requestUnlock(email);
      if (mounted) {
        setState(() {
          _message = message;
          _success = true;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteLink() async {
    final controller = TextEditingController();
    final rawLink = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dán liên kết từ email'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'bmud://account-action?action=...&token=...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (rawLink == null || rawLink.trim().isEmpty || !mounted) return;

    final uri = Uri.tryParse(rawLink.trim());
    final action = uri?.queryParameters['action'];
    final token = uri?.queryParameters['token'];
    if (uri?.scheme != 'bmud' ||
        uri?.host != 'account-action' ||
        token == null ||
        (action != 'unlock' && action != 'reset-password')) {
      setState(() {
        _success = false;
        _message = 'Liên kết không hợp lệ';
      });
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountActionScreen(action: action!, token: token),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
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
                Text(
                  _isReset
                      ? 'Nhập email để nhận liên kết đặt lại mật khẩu.'
                      : 'Nhập email để nhận liên kết mở khóa tài khoản.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi liên kết qua email'),
                ),
                TextButton(
                  onPressed: _loading ? null : _pasteLink,
                  child: const Text('Dán liên kết đã nhận'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _success
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
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
