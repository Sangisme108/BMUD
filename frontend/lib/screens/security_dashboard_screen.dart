import 'package:flutter/material.dart';

import '../services/security_service.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() =>
      _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  final _securityService = SecurityService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _securityService.getDashboard();
  }

  Future<void> _reload() async {
    setState(() => _future = _securityService.getDashboard());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bảo mật tài khoản'),
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data ?? {};
          final alerts = data['alerts'] as List<dynamic>? ?? [];
          final events = data['events'] as List<dynamic>? ?? [];
          final total = _asInt(data['total_logins']);
          final low = _asInt(data['low_count']);
          final medium = _asInt(data['medium_count']);
          final high = _asInt(data['high_count']);
          final needsAttention = medium + high;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _StatusCard(
                  needsAttention: needsAttention,
                  total: total,
                  safe: low,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SmallMetric(
                        label: 'An toàn',
                        value: low,
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SmallMetric(
                        label: 'Theo dõi',
                        value: medium,
                        icon: Icons.info_outline,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SmallMetric(
                        label: 'Rủi ro',
                        value: high,
                        icon: Icons.error_outline,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Cảnh báo',
                  count: alerts.length,
                ),
                const SizedBox(height: 10),
                if (alerts.isEmpty)
                  const _EmptyBlock(
                    icon: Icons.shield_outlined,
                    title: 'Không có cảnh báo',
                    message: 'Chưa phát hiện hoạt động bất thường.',
                  )
                else
                  ...alerts.map((raw) {
                    final alert = raw as Map<String, dynamic>;
                    return _SecurityItem(
                      icon: Icons.warning_amber_rounded,
                      title: alert['device_name']?.toString() ??
                          'Thiết bị không xác định',
                      description:
                          alert['reason']?.toString() ?? 'Cần kiểm tra lại.',
                      time: _formatTime(alert['login_time']),
                      ip: alert['ip_address']?.toString(),
                      riskLevel: alert['risk_level']?.toString() ?? 'LOW',
                    );
                  }),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Nhật ký gần đây',
                  count: events.length,
                ),
                const SizedBox(height: 10),
                if (events.isEmpty)
                  const _EmptyBlock(
                    icon: Icons.history_toggle_off,
                    title: 'Chưa có nhật ký',
                    message: 'Các sự kiện bảo mật sẽ hiển thị tại đây.',
                  )
                else
                  ...events.map((raw) {
                    final event = raw as Map<String, dynamic>;
                    return _SecurityItem(
                      icon: _eventIcon(event['event_type']?.toString()),
                      title: event['title']?.toString() ?? 'Sự kiện bảo mật',
                      description: event['description']?.toString() ?? '',
                      time: _formatTime(event['created_at']),
                      ip: event['ip_address']?.toString(),
                      riskLevel: event['risk_level']?.toString() ?? 'LOW',
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  IconData _eventIcon(String? type) {
    final raw = (type ?? '').toLowerCase();
    if (raw.contains('register')) return Icons.person_add_alt_1_outlined;
    if (raw.contains('otp')) return Icons.password_outlined;
    if (raw.contains('device')) return Icons.devices_other_outlined;
    if (raw.contains('failed') || raw.contains('blocked')) {
      return Icons.report_gmailerrorred_outlined;
    }
    if (raw.contains('password')) return Icons.key_outlined;
    if (raw.contains('recovery')) return Icons.lock_reset_outlined;
    return Icons.shield_outlined;
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
}

class _StatusCard extends StatelessWidget {
  final int needsAttention;
  final int total;
  final int safe;

  const _StatusCard({
    required this.needsAttention,
    required this.total,
    required this.safe,
  });

  @override
  Widget build(BuildContext context) {
    final ok = needsAttention == 0;
    final color = ok ? const Color(0xFF16A34A) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(
              ok ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Tài khoản an toàn' : 'Cần kiểm tra bảo mật',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? '$safe/$total hoạt động gần đây ở mức an toàn.'
                      : '$needsAttention hoạt động cần chú ý trong nhật ký.',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _SmallMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String time;
  final String? ip;
  final String riskLevel;

  const _SecurityItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.time,
    required this.ip,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final risk = _RiskStyle.from(riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
            backgroundColor: risk.background,
            child: Icon(icon, color: risk.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _MetaChip(icon: Icons.schedule, label: time),
                    if (ip != null && ip!.isNotEmpty)
                      _MetaChip(icon: Icons.language, label: ip!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RiskChip(style: risk),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RiskChip extends StatelessWidget {
  final _RiskStyle style;

  const _RiskChip({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyBlock({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFEAF7EF),
            child: Icon(icon, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 50, color: Color(0xFF2563EB)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _RiskStyle {
  final String label;
  final Color color;
  final Color background;

  const _RiskStyle({
    required this.label,
    required this.color,
    required this.background,
  });

  factory _RiskStyle.from(String value) {
    final risk = value.toUpperCase();
    if (risk == 'HIGH') {
      return const _RiskStyle(
        label: 'Cao',
        color: Color(0xFFDC2626),
        background: Color(0xFFFEE2E2),
      );
    }
    if (risk == 'MEDIUM') {
      return const _RiskStyle(
        label: 'Vừa',
        color: Color(0xFFD97706),
        background: Color(0xFFFFF7ED),
      );
    }
    return const _RiskStyle(
      label: 'An toàn',
      color: Color(0xFF16A34A),
      background: Color(0xFFEAF7EF),
    );
  }
}
