import 'package:flutter/material.dart';

import 'marketplace_theme.dart';

/// An intentionally-empty marketplace must look intentional (Task 30) -
/// never filled with fake sample listings to look "alive".
class MarketplaceEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const MarketplaceEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: MarketTheme.muted, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MarketTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
