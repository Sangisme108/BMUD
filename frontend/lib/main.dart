import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'screens/account_action_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const SecurityLoginApp());
}

class SecurityLoginApp extends StatefulWidget {
  const SecurityLoginApp({super.key});

  @override
  State<SecurityLoginApp> createState() => _SecurityLoginAppState();
}

class _SecurityLoginAppState extends State<SecurityLoginApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledLink;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  Future<void> _initializeDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) _handleDeepLink(initialLink);
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'bmud' || uri.host != 'account-action') return;
    final action = uri.queryParameters['action'];
    final token = uri.queryParameters['token'];
    if (action == null || token == null || token.isEmpty) return;
    if (action != 'unlock' && action != 'reset-password') return;
    if (_lastHandledLink == uri.toString()) return;
    _lastHandledLink = uri.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AccountActionScreen(action: action, token: token),
        ),
      );
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Abnormal Login Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _authService = AuthService();
  late final Future<bool> _hasSession = _loadSession();

  Future<bool> _loadSession() async {
    final token = await _authService.getToken();
    final user = await _authService.getSavedUser();
    return token != null && user != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
