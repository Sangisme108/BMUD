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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = histories[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.deviceName ?? 'Không xác định',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          RiskBadge(riskLevel: item.riskLevel),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('IP: ${item.ipAddress}'),
                      Text('Thời gian: ${item.loginTime}'),
                      Text('Trạng thái: ${item.loginStatus}'),
                      Text('Lý do: ${item.reason ?? ''}'),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: histories.length,
          );
        },
      ),
    );
  }
}
