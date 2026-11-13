import 'package:flutter/material.dart';

class NdviChart extends StatelessWidget {
  const NdviChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: Text('NDVI Vegetation Trend Chart')),
    );
  }
}
