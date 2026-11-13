import 'package:flutter/material.dart';

class TreatmentStepCard extends StatelessWidget {
  final int step;
  final String title;
  final String description;

  const TreatmentStepCard({super.key, required this.step, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('$step')),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(description),
    );
  }
}
