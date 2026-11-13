import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String label;
  const RiskBadge({super.key, this.label = 'মাঝারি থেকে বেশি ঝুঁকি'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange),
      ),
      child: Text(label, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
    );
  }
}
