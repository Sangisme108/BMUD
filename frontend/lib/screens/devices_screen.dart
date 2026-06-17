import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/security_service.dart';
import 'login_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _securityService = SecurityService();
  final _authService = AuthService();
  late Future<List<Map<String, dynamic>>> _future;
  String? _revokingSessionId;

  @override
  void initState() {
    super.initState();
    _future = _securityService.getDevices();
  }

  Future<void> _reload() async {
    setState(() => _future = _securityService.getDevices());
    await _future;
  }

  Future<void> _confirmRevoke(Map<String, dynamic> device) async {
    if (_revokingSessionId != null) return;

    final sessionId = device['sessionId']?.toString() ?? '';
    final isCurrent = device['isCurrentDevice'] == true;
    final deviceName = device['deviceName']?.toString() ?? 'Thiết bị này';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gỡ thiết bị?'),
        content: Text(
          isCurrent
              ? 'Bạn đang gỡ thiết bị hiện tại. Ứng dụng sẽ đăng xuất ngay sau khi xác nhận.'
              : 'Thiết bị "$deviceName" sẽ bị đăng xuất ngay và phải xác minh OTP khi đăng nhập lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ thiết bị'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _revokeDevice(sessionId, isCurrent);
  }

  Future<void> _revokeDevice(String sessionId, bool isCurrent) async {
    setState(() => _revokingSessionId = sessionId);
    try {
      final result = await _securityService.revokeDevice(sessionId);
      if (!mounted) return;

      if (isCurrent || result['revokedCurrentDevice'] == true) {
        await _authService.clearSession(keepDeviceId: true);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Đã gỡ thiết bị thành công',
          ),
        ),
      );
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _revokingSessionId = null);
    }
  }

  String _formatTime(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return 'Không rõ';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month ${hour}h$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Thiết bị đã đăng nhập'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final devices = snapshot.data ?? [];
          if (devices.isEmpty) {
            return const Center(child: Text('Chưa có thiết bị đăng nhập'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final device = devices[index];
                final sessionId = device['sessionId']?.toString() ?? '';
                final os =
                    device['operatingSystem']?.toString() ?? 'Không xác định';
                final isCurrent = device['isCurrentDevice'] == true;
                final isTrusted = device['isTrusted'] == true;
                final recovery =
                    device['messageRecoveryStatus']?.toString() ?? 'NOT_RECOVERED';
                final revoking = _revokingSessionId == sessionId;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFF1F5F9),
                        child: Icon(_deviceIcon(os), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device['deviceName']?.toString() ?? os,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF7EF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Thiết bị này',
                                      style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hệ điều hành: $os',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                height: 1.25,
                              ),
                            ),
                            Text(
                              'IP: ${device['ipAddress'] ?? 'Không rõ'}',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                height: 1.25,
                              ),
                            ),
                            Text(
                              'Hoạt động cuối: ${_formatTime(device['lastSeenAt'])}',
                              style: const TextStyle(
                                color: Color(0xFF4B5563),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _StatusChip(
                                  label: isTrusted ? 'Tin cậy' : 'Chưa tin cậy',
                                  color: isTrusted
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                  background: isTrusted
                                      ? const Color(0xFFEAF7EF)
                                      : const Color(0xFFFFF7ED),
                                ),
                                _StatusChip(
                                  label: recovery == 'RECOVERED'
                                      ? 'Đã khôi phục tin nhắn'
                                      : 'Chưa khôi phục tin nhắn',
                                  color: const Color(0xFF64748B),
                                  background: const Color(0xFFF1F5F9),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      revoking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _confirmRevoke(device),
                              child: const Text('Gỡ'),
                            ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _deviceIcon(String os) {
    final raw = os.toLowerCase();
    if (raw.contains('android')) return Icons.android;
    if (raw.contains('ios') || raw.contains('iphone')) {
      return Icons.phone_iphone;
    }
    if (raw.contains('windows') || raw.contains('mac')) return Icons.computer;
    return Icons.devices_other_outlined;
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
