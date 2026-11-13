import 'package:flutter/material.dart';

class SatelliteMap extends StatelessWidget {
  const SatelliteMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.green.shade900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Text('🛰️ Satellite Map & NDVI Overlay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
