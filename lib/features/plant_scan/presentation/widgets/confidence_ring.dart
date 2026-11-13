import 'package:flutter/material.dart';

class ConfidenceRing extends StatelessWidget {
  final double confidence;
  const ConfidenceRing({super.key, this.confidence = 92.0});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 36,
      backgroundColor: Colors.green.shade100,
      child: Text('${confidence.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
    );
  }
}
