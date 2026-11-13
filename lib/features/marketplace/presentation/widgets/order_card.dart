import 'package:flutter/material.dart';

import '../../data/exact_numbers.dart';
import '../../data/marketplace_models.dart';
import 'marketplace_status_badge.dart';
import 'marketplace_theme.dart';

class OrderCard extends StatelessWidget {
  final MarketplaceOrder order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    order.listing.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MarketTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                MarketplaceStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'বিক্রেতা: ${order.sellerDisplayName ?? 'বিক্রেতা'} · ক্রেতা: ${order.buyerDisplayName ?? 'ক্রেতা'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: MarketTheme.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${order.quantity} ${order.quantityUnit} · ৳${formatMinorUnitsToMajor(order.totalAmountMinor)}',
              style: const TextStyle(color: MarketTheme.mint, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
