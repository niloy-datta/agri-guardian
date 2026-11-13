import 'package:flutter/material.dart';

class HealthScoreCard extends StatelessWidget {
  final double score;
  const HealthScoreCard({super.key, this.score = 72.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('জমির স্বাস্থ্য স্কোর', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('${score.toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }
}
