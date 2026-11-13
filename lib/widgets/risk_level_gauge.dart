import 'package:flutter/material.dart';

/// Segmented Risk Level Gauge (ঝুঁকির মাত্রা: কম, মাঝারি, বেশি)
class RiskLevelGauge extends StatelessWidget {
  final int activeSegment; // 1: Low, 2: Moderate, 3: High, 4: Critical
  final String levelText;
  final String description;

  const RiskLevelGauge({
    super.key,
    this.activeSegment = 3,
    this.levelText = 'মাঝারি থেকে বেশি',
    this.description = 'বর্তমান অবস্থায় দ্রুত নজরদারি ও ব্যবস্থাপনা প্রয়োজন।',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'ঝুঁকির মাত্রা',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                levelText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (index) {
              final segmentNumber = index + 1;
              final isFilled = segmentNumber <= activeSegment;
              Color segColor;
              switch (index) {
                case 0:
                  segColor = const Color(0xFF22C55E);
                  break;
                case 1:
                  segColor = const Color(0xFFF59E0B);
                  break;
                case 2:
                  segColor = const Color(0xFFEA580C);
                  break;
                default:
                  segColor = const Color(0xFFEF4444);
              }

              return Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isFilled ? segColor : segColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
