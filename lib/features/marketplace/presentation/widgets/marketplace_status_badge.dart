import 'package:flutter/material.dart';

import 'marketplace_theme.dart';

/// Every status is communicated with TEXT, never color alone (Task 55).
class MarketplaceStatusBadge extends StatelessWidget {
  final String status;

  const MarketplaceStatusBadge({super.key, required this.status});

  static const Map<String, String> _labelsBn = {
    'DRAFT': 'খসড়া',
    'ACTIVE': 'সক্রিয়',
    'SOLD_OUT': 'বিক্রি শেষ',
    'CLOSED': 'বন্ধ',
    'CANCELLED': 'বাতিল',
    'WITHDRAWN': 'প্রত্যাহার',
    'ACCEPTED': 'গৃহীত',
    'REJECTED': 'প্রত্যাখ্যাত',
    'EXPIRED': 'মেয়াদোত্তীর্ণ',
    'CONFIRMED': 'নিশ্চিত',
  };

  Color _color(String status) {
    switch (status) {
      case 'ACTIVE':
      case 'ACCEPTED':
      case 'CONFIRMED':
        return MarketTheme.green;
      case 'SOLD_OUT':
        return MarketTheme.orange;
      case 'CLOSED':
      case 'CANCELLED':
      case 'REJECTED':
      case 'EXPIRED':
        return MarketTheme.red;
      case 'WITHDRAWN':
        return MarketTheme.muted;
      default:
        return MarketTheme.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    final label = _labelsBn[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}
