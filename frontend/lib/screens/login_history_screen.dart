import 'package:flutter/material.dart';

import '../models/login_history.dart';
import '../services/security_service.dart';
import '../widgets/risk_badge.dart';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final _securityService = SecurityService();
  late Future<List<LoginHistory>> _future;

  @override
  void initState() {
    super.initState();
    _future = _securityService.getLoginHistory();
  }

  Future<void> _reload() async {
    setState(() => _future = _securityService.getLoginHistory());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đăng nhập')),
      body: FutureBuilder<List<LoginHistory>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final histories = snapshot.data ?? [];
          if (histories.isEmpty) {
            return const Center(child: Text('Chưa có lịch sử đăng nhập'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: histories.length,
              itemBuilder: (context, index) {
                final item = histories[index];
                return _TimelineEntry(
                  item: item,
                  isLast: index == histories.length - 1,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final LoginHistory item;
  final bool isLast;

  const _TimelineEntry({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final success = item.loginStatus == 'SUCCESS';
    final color = success
        ? const Color(0xFF31A24C)
        : Theme.of(context).colorScheme.error;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.deviceName ?? 'Thiết bị không xác định',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        RiskBadge(riskLevel: item.riskLevel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(icon: Icons.schedule, text: item.loginTime),
                    _InfoLine(icon: Icons.devices, text: 'Thiết bị: ${item.deviceName ?? 'Không rõ'}'),
                    _InfoLine(icon: Icons.memory, text: 'Hệ điều hành: ${_guessOs(item.userAgent)}'),
                    _InfoLine(icon: Icons.public, text: 'IP: ${item.ipAddress}'),
                    const _InfoLine(icon: Icons.flag, text: 'Quốc gia: Chưa xác định'),
                    _InfoLine(icon: Icons.verified, text: 'Trạng thái: ${success ? 'Thành công' : 'Thất bại'}'),
                    if ((item.userAgent ?? '').isNotEmpty)
                      _InfoLine(icon: Icons.code, text: 'User-Agent: ${item.userAgent}'),
                    if ((item.reason ?? '').isNotEmpty)
                      _InfoLine(icon: Icons.info_outline, text: 'Lý do: ${item.reason}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _guessOs(String? userAgent) {
    final raw = (userAgent ?? '').toLowerCase();
    if (raw.contains('android')) return 'Android';
    if (raw.contains('iphone') || raw.contains('ios')) return 'iOS';
    if (raw.contains('windows')) return 'Windows';
    if (raw.contains('mac')) return 'macOS';
    if (raw.contains('linux')) return 'Linux';
    return 'Không xác định';
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
