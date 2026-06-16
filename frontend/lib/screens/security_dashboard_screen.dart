import 'package:flutter/material.dart';

import '../services/security_service.dart';
import '../widgets/risk_badge.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard bảo mật')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data ?? {};
          final alerts = (data['alerts'] as List<dynamic>? ?? []);
          final events = (data['events'] as List<dynamic>? ?? []);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatTile(
                    title: 'Tổng',
                    value: data['total_logins'].toString(),
                  ),
                  _StatTile(title: 'LOW', value: data['low_count'].toString()),
                  _StatTile(
                    title: 'MEDIUM',
                    value: data['medium_count'].toString(),
                  ),
                  _StatTile(
                    title: 'HIGH',
                    value: data['high_count'].toString(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Cảnh báo gần đây',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (alerts.isEmpty)
                const Text('Không có cảnh báo')
              else
                ...alerts.map((raw) {
                  final alert = raw as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text(
                        alert['device_name']?.toString() ?? 'Không xác định',
                      ),
                      subtitle: Text(
                        'IP: ${alert['ip_address']}\n'
                        'Thời gian: ${alert['login_time']}\n'
                        'Lý do: ${alert['reason']}',
                      ),
                      trailing: RiskBadge(
                        riskLevel: alert['risk_level']?.toString() ?? 'LOW',
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Text(
                'Nhật ký bảo mật gần đây',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (events.isEmpty)
                const Text('Chưa có sự kiện bảo mật')
              else
                ...events.map((raw) {
                  final event = raw as Map<String, dynamic>;
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_eventIcon(event['event_type']?.toString())),
                      ),
                      title: Text(event['title']?.toString() ?? 'Sự kiện'),
                      subtitle: Text(
                        '${event['description'] ?? ''}\n'
                        'IP: ${event['ip_address'] ?? 'Không rõ'}\n'
                        'Thời gian: ${event['created_at'] ?? ''}',
                      ),
                      trailing: RiskBadge(
                        riskLevel: event['risk_level']?.toString() ?? 'LOW',
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  IconData _eventIcon(String? type) {
    final raw = (type ?? '').toLowerCase();
    if (raw.contains('login_failed') || raw.contains('blocked')) {
      return Icons.warning_amber;
    }
    if (raw.contains('otp')) return Icons.password;
    if (raw.contains('device')) return Icons.devices_other;
    if (raw.contains('recovery')) return Icons.lock_reset;
    if (raw.contains('password')) return Icons.key;
    return Icons.security;
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;

  const _StatTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
