import 'package:flutter/material.dart';

import '../shared/demo/showcase_story.dart';

class MarketIntelligenceScreen extends StatefulWidget {
  const MarketIntelligenceScreen({super.key});

  @override
  State<MarketIntelligenceScreen> createState() =>
      _MarketIntelligenceScreenState();
}

class _MarketIntelligenceScreenState extends State<MarketIntelligenceScreen> {
  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const blue = Color(0xFF4DA3FF);
  static const orange = Color(0xFFFFB020);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  int _selectedFilter = 0; // 0 = 7D, 1 = 1M, 2 = 3M, 3 = 1Y

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // ================= TOP BAR =================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'বাজার দর ও এআই পরামর্শ',
                              style: TextStyle(
                                color: text,
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Market Intelligence • ${DemoStory.demoTagBn} দর · DAM সংযুক্ত নয়',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: green.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              color: green,
                              size: 14,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '${DemoStory.demoTagBn} দর',
                              style: TextStyle(
                                color: green,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= SCROLLABLE CONTENT =================
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // HERO PRICE CARD (৳ 2,430 / maund)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: line),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF132D22),
                              Color(0xFF0C1E17),
                              Color(0xFF071410),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${DemoStory.crop.cropBn} (${DemoStory.crop.varietyShortBn})',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: green.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.trending_up_rounded,
                                        color: green,
                                        size: 14,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        '+১২% এই সপ্তাহে',
                                        style: TextStyle(
                                          color: green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DemoStory.market.homeMarketBn} • ডেমো নমুনা দর',
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                            const SizedBox(height: 14),

                            // Price big display
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  '৳ ২,৪৩০',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '/ মণ (৪০ কেজি)',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(color: line, height: 1),
                            const SizedBox(height: 12),

                            // Metrics: চাহিদা ও স্থিতিশীলতা
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _PriceMetric(
                                  title: 'বর্তমান চাহিদা',
                                  value: 'উচ্চ (High)',
                                  color: green,
                                ),
                                _PriceMetric(
                                  title: 'বাজার স্থিতিশীলতা',
                                  value: 'মাঝারি (Moderate)',
                                  color: orange,
                                ),
                                _PriceMetric(
                                  title: 'জাতীয় গড় দর',
                                  value: '৳ ২,৩৮০',
                                  color: text,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // LUMINOUS PRICE CHART
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'মূল্য প্রবণতা চার্ট',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                // 7D / 1M / 3M Selector
                                Row(
                                  children: [
                                    _ChartFilter(
                                      label: '7D',
                                      selected: _selectedFilter == 0,
                                      onTap: () => setState(() => _selectedFilter = 0),
                                    ),
                                    _ChartFilter(
                                      label: '1M',
                                      selected: _selectedFilter == 1,
                                      onTap: () => setState(() => _selectedFilter = 1),
                                    ),
                                    _ChartFilter(
                                      label: '3M',
                                      selected: _selectedFilter == 2,
                                      onTap: () => setState(() => _selectedFilter = 2),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Luminous Sparkline Graph
                            SizedBox(
                              height: 110,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _PriceChartPainter(color: green),
                              ),
                            ),

                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('১২ সেপ্টে', style: TextStyle(color: muted, fontSize: 10)),
                                Text('১৪ সেপ্টে', style: TextStyle(color: muted, fontSize: 10)),
                                Text('১৬ সেপ্টে', style: TextStyle(color: muted, fontSize: 10)),
                                Text('১৮ সেপ্টে', style: TextStyle(color: muted, fontSize: 10)),
                                Text('আজ (১৯ সেপ্টে)',
                                    style: TextStyle(
                                      color: green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // AI SELLING RECOMMENDATION CARDS
                      const Text(
                        'এআই বিক্রয় পরামর্শ (AI Selling Advice)',
                        style: TextStyle(
                          color: text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _AdviceCard(
                        title: 'আজ ৩০% ফসল বিক্রি করতে পারেন',
                        desc:
                            'বর্তমান দর গত মাসের সর্বোচ্চে অবস্থান করছে। আংশিক বিক্রি করে ঝুঁকি কমানো লাভজনক।',
                        badge: 'পরামর্শ',
                        color: green,
                        icon: Icons.sell_outlined,
                      ),
                      const SizedBox(height: 8),

                      _AdviceCard(
                        title: 'বাকি ৭০% আরও ২ দিন ধরে রাখুন',
                        desc:
                            'আসন্ন শুক্রবারে মিল মালিকদের চাহিদা আরও বৃদ্ধি পেয়ে দর আরও ২০-৩০ টাকা বাড়তে পারে।',
                        badge: 'ধরে রাখুন',
                        color: orange,
                        icon: Icons.hourglass_top_rounded,
                      ),
                      const SizedBox(height: 8),

                      _AdviceCard(
                        title: 'বৃষ্টির কারণে পরিবহন সতর্কতা',
                        desc:
                            'ডেমো পূর্বাভাসে আগামী দুই দিন বৃষ্টি ও বজ্রঝড়ের ঝুঁকি রয়েছে, খোলা ট্রাকে ধান পরিবহন থেকে বিরত থাকুন।',
                        badge: 'সতর্কতা',
                        color: blue,
                        icon: Icons.cloud_sync_outlined,
                      ),

                      const SizedBox(height: 18),

                      // NEARBY MARKETS COMPARISON TABLE
                      const Text(
                        'নিকটবর্তী বাজারসমূহ (Nearby Markets)',
                        style: TextStyle(
                          color: text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _MarketPriceRow(
                        marketName: DemoStory.market.homeMarketBn,
                        distance: '৪ কিমি',
                        price: '৳ ২,৪৩০',
                        trend: '+৳ ৫০',
                        isUp: true,
                        isBest: true,
                      ),
                      const SizedBox(height: 6),
                      const _MarketPriceRow(
                        marketName: 'ময়মনসিংহ বড় বাজার',
                        distance: '২৮ কিমি',
                        price: '৳ ২,৪১০',
                        trend: '+৳ ২০',
                        isUp: true,
                        isBest: false,
                      ),
                      const SizedBox(height: 6),
                      const _MarketPriceRow(
                        marketName: 'গাজীপুর আড়ত',
                        distance: '৬৫ কিমি',
                        price: '৳ ২,৪৪০',
                        trend: '+৳ ১০',
                        isUp: true,
                        isBest: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1D18),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1D382F)),
        ),
        child: Icon(icon, color: const Color(0xFFF5FFF8), size: 18),
      ),
    );
  }
}

class _PriceMetric extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _PriceMetric({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFF8EA69A), fontSize: 10.5),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ChartFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChartFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF20E27A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : const Color(0xFF8EA69A),
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final String title;
  final String desc;
  final String badge;
  final Color color;
  final IconData icon;

  const _AdviceCard({
    required this.title,
    required this.desc,
    required this.badge,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1D18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D382F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFF5FFF8),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xFF8EA69A),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketPriceRow extends StatelessWidget {
  final String marketName;
  final String distance;
  final String price;
  final String trend;
  final bool isUp;
  final bool isBest;

  const _MarketPriceRow({
    required this.marketName,
    required this.distance,
    required this.price,
    required this.trend,
    required this.isUp,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF20E27A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isBest ? const Color(0xFF10281F) : const Color(0xFF0D1D18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBest ? green.withOpacity(0.4) : const Color(0xFF1D382F),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      marketName,
                      style: const TextStyle(
                        color: Color(0xFFF5FFF8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: green.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'সেরা দর',
                          style: TextStyle(
                            color: green,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'দূরত্ব: $distance',
                  style: const TextStyle(
                    color: Color(0xFF8EA69A),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFFF5FFF8),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                trend,
                style: TextStyle(
                  color: isUp ? green : const Color(0xFFFF5555),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  final Color color;

  _PriceChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.75),
      Offset(size.width * 0.25, size.height * 0.65),
      Offset(size.width * 0.50, size.height * 0.50),
      Offset(size.width * 0.75, size.height * 0.35),
      Offset(size.width, size.height * 0.15),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Fill Gradient
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line stroke
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // End point dot with glow
    final lastPoint = points.last;
    canvas.drawCircle(
      lastPoint,
      7,
      Paint()..color = color.withOpacity(0.3),
    );
    canvas.drawCircle(
      lastPoint,
      4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      lastPoint,
      2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
