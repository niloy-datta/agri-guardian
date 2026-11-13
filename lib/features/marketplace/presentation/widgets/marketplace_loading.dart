import 'package:flutter/material.dart';

import 'marketplace_theme.dart';

class MarketplaceLoading extends StatelessWidget {
  const MarketplaceLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: MarketTheme.green, strokeWidth: 2.5),
    );
  }
}
