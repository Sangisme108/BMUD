import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'friends_screen.dart';
import 'login_history_screen.dart';
import 'login_screen.dart';
import 'security_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userJson;

  const HomeScreen({super.key, this.userJson});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (widget.userJson != null) {
      setState(() => _user = User.fromJson(widget.userJson!));
      return;
    }
    final savedUser = await _authService.getSavedUser();
    setState(() => _user = savedUser);
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang chủ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Xin chào ${_user?.fullName ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(_user?.email ?? ''),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('Xem lịch sử đăng nhập'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SecurityDashboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.security),
                label: const Text('Xem dashboard bảo mật'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  );
                },
                icon: const Icon(Icons.forum),
                label: const Text('Bạn bè và tin nhắn'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
