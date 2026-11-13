import 'package:flutter/material.dart';

class FieldStatusCard extends StatelessWidget {
  final String message;

  const FieldStatusCard({
    super.key,
    this.message = 'উত্তর-পূর্ব পাশে পানি বেশি • নজরদারি প্রয়োজন',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(message),
    );
  }
}
