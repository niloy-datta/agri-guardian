import 'package:flutter/material.dart';

class IrrigationScreen extends StatelessWidget {
  const IrrigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('স্মার্ট সেচ')),
      body: const Center(child: Text('💧 আজ সেচ দেবেন না • মাটির আর্দ্রতা পর্যাপ্ত')),
    );
  }
}
