import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const SecurityLoginApp());
}

class SecurityLoginApp extends StatelessWidget {
  const SecurityLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Abnormal Login Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
