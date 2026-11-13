import 'package:flutter/material.dart';

import '../../data/exact_numbers.dart';
import '../../data/marketplace_models.dart';
import 'marketplace_status_badge.dart';
import 'marketplace_theme.dart';

/// Shown both in the seller's bid inbox and in "my bids" - never labels
/// any bid a winner/best/recommended (the absolute bidding UX rule,
/// Task 39). `showListingContext` switches between "which buyer" (inbox)
/// and "which product" (my bids) framing.
class BidCard extends StatelessWidget {
  final MarketplaceBid bid;
  final bool showListingContext;
  final Widget? trailing;

  const BidCard({
    super.key,
    required this.bid,
    this.showListingContext = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    int? totalMinor;
    try {
      totalMinor = estimateTotalMinorUnits(bid.quantity, bid.unitPriceMinor);
    } on ExactNumberFormatException {
      totalMinor = null;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MarketTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showListingContext
                      ? bid.listing.productName
                      : (bid.buyer.displayName ?? 'ক্রেতা'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MarketTheme.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              MarketplaceStatusBadge(status: bid.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${bid.quantity} ${bid.listing.quantityUnit ?? ''} · ৳${formatMinorUnitsToMajor(bid.unitPriceMinor)}/একক',
            style: const TextStyle(color: MarketTheme.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (totalMinor != null) ...[
            const SizedBox(height: 2),
            Text(
              'আনুমানিক মোট: ৳${formatMinorUnitsToMajor(totalMinor)}',
              style: const TextStyle(color: MarketTheme.mint, fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ],
          if (bid.note != null && bid.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bid.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: MarketTheme.muted, fontSize: 11.5),
            ),
          ],
          if (bid.expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'মেয়াদ: ${bid.expiresAt!.toLocal()}'.split('.').first,
              style: const TextStyle(color: MarketTheme.muted, fontSize: 10.5),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
