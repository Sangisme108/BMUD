import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String riskLevel;

  const RiskBadge({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final color = switch (riskLevel) {
      'HIGH' => Colors.red,
      'MEDIUM' => Colors.orange,
      _ => Colors.green,
    };

    return Chip(
      label: Text(riskLevel),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
