import 'package:flutter/material.dart';
import '../widgets/ndvi_chart.dart';

class FieldInsightsScreen extends StatelessWidget {
  const FieldInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('স্যাটেলাইট ইনসাইটস')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NdviChart(),
        ],
      ),
    );
  }
}
