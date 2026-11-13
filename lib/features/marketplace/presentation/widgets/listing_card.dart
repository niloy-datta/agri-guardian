import 'package:flutter/material.dart';

import '../../data/exact_numbers.dart';
import '../../data/marketplace_models.dart';
import 'marketplace_status_badge.dart';
import 'marketplace_theme.dart';

/// Renders only real backend values (Task 28/57) - no fake market rate,
/// buyer count, rating, or "best seller" badge.
class ListingCard extends StatelessWidget {
  final MarketplaceListing listing;
  final VoidCallback onTap;

  const ListingCard({super.key, required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priceText = listing.askingPriceMinor == null
        ? 'দর প্রস্তাব করুন'
        : '৳${formatMinorUnitsToMajor(listing.askingPriceMinor!)} / ${listing.quantityUnit}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MarketTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MarketTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (listing.listingKind == 'FISH' ? MarketTheme.blue : MarketTheme.green)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    listing.listingKind == 'FISH' ? 'মাছ' : 'ফসল',
                    style: TextStyle(
                      color: listing.listingKind == 'FISH' ? MarketTheme.blue : MarketTheme.green,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    listing.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MarketTheme.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                MarketplaceStatusBadge(status: listing.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${listing.quantityAvailable} ${listing.quantityUnit} উপলব্ধ',
              style: const TextStyle(color: MarketTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              priceText,
              style: const TextStyle(color: MarketTheme.mint, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (listing.district != null) _Chip(listing.district!),
                _Chip(_deliveryLabel(listing.deliveryMode)),
                if (listing.grade != null) _Chip('গ্রেড: ${listing.grade}'),
                if (listing.isFutureHarvest) _Chip('ভবিষ্যৎ ফলন', color: MarketTheme.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _deliveryLabel(String mode) => switch (mode) {
        'PICKUP' => 'সংগ্রহ',
        'DELIVERY' => 'ডেলিভারি',
        _ => 'সংগ্রহ/ডেলিভারি',
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip(this.label, {this.color = MarketTheme.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color == MarketTheme.line ? MarketTheme.line : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == MarketTheme.line ? MarketTheme.muted : color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
