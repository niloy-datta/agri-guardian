import 'package:flutter/material.dart';
import '../widgets/satellite_map.dart';
import '../widgets/health_score_card.dart';

class FieldsScreen extends StatelessWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('আমার জমি')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SatelliteMap(),
          SizedBox(height: 16),
          HealthScoreCard(),
        ],
      ),
    );
  }
}
