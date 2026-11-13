import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../shared/demo/showcase_story.dart';

class FieldInsightsScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const FieldInsightsScreen({super.key, this.onBack});

  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const card2 = Color(0xFF10271E);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const blue = Color(0xFF53A9FF);
  static const orange = Color(0xFFFFB020);
  static const red = Color(0xFFFF6060);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
              children: [
                // HEADER
                Row(
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: onBack ?? () => Navigator.pop(context),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.insFieldInsightsTitle,
                            style: TextStyle(
                              color: text,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            DemoStory.fieldCropEn,
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    _Pill(
                      icon: Icons.auto_awesome_rounded,
                      // Showcase content - never labelled as live AI.
                      text: context.l10n.insDemoBadge,
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // HERO HEALTH CARD
                Container(
                  height: 210,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF184B33),
                        Color(0xFF0A2A1C),
                        Color(0xFF071510),
                      ],
                    ),
                    border: Border.all(color: green.withOpacity(.25)),
                    boxShadow: [
                      BoxShadow(
                        color: green.withOpacity(.06),
                        blurRadius: 32,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // SCORE
                      SizedBox(
                        width: 125,
                        height: 125,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 118,
                              height: 118,
                              child: CircularProgressIndicator(
                                value: .82,
                                strokeWidth: 9,
                                backgroundColor: green.withOpacity(.12),
                                color: green,
                                strokeCap: StrokeCap.round,
                              ),
                            ),

                            const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '82',
                                  style: TextStyle(
                                    color: text,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 18),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Pill(icon: Icons.eco_rounded, text: 'HEALTHY'),

                            SizedBox(height: 13),

                            Text(
                              context.l10n.insHealthyTitle,
                              style: TextStyle(
                                color: text,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            SizedBox(height: 7),

                            Text(
                              context.l10n.insMostlyHealthy((context.l10n.isBangla ? DemoStory.issues.waterloggingZoneBn : DemoStory.issues.waterloggingZoneEn)),
                              style: TextStyle(
                                color: muted,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // METRICS
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        icon: Icons.eco_outlined,
                        value: '+5%',
                        label: 'NDVI',
                        color: green,
                      ),
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: _Metric(
                        icon: Icons.water_drop_outlined,
                        value: '63%',
                        label: context.l10n.satSoilMoisture,
                        color: blue,
                      ),
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: _Metric(
                        icon: Icons.bug_report_outlined,
                        value: context.l10n.riskLow,
                        label: context.l10n.insPestRisk,
                        color: green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // TREND
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.insCropHealthTrend,
                        style: TextStyle(
                          color: text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _Pill(icon: Icons.trending_up_rounded, text: '+5.2%'),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  height: 210,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: line),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          painter: _TrendPainter(),
                          child: const SizedBox.expand(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.insChartDay(12),
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                          Text(
                            context.l10n.insChartDay(14),
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                          Text(
                            context.l10n.insChartDay(16),
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                          Text(
                            context.l10n.todayLabel,
                            style: TextStyle(
                              color: green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // AI INSIGHT
                Text(
                  context.l10n.insAiInsight,
                  style: TextStyle(
                    color: text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: green.withOpacity(.065),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: green.withOpacity(.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: green,
                            size: 22,
                          ),
                          SizedBox(width: 9),
                          Text(
                            context.l10n.insMostImportant,
                            style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 14),

                      Text(
                        context.l10n.insWaterSignal((context.l10n.isBangla ? DemoStory.issues.waterloggingZoneBn : DemoStory.issues.waterloggingZoneEn)),
                        style: TextStyle(
                          color: text,
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      SizedBox(height: 8),

                      Text(
                        context.l10n.insAdvice,
                        style: TextStyle(
                          color: muted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // EVIDENCE
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.insWhyAlert,
                        style: TextStyle(
                          color: text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      SizedBox(height: 15),

                      _Evidence(
                        icon: Icons.cloudy_snowing,
                        title: context.l10n.insRecentRainfall,
                        value: context.l10n.riskHigh,
                        color: blue,
                      ),

                      SizedBox(height: 12),

                      _Evidence(
                        icon: Icons.water_drop_outlined,
                        title: context.l10n.insWaterSignalTitle,
                        value: context.l10n.insDetected,
                        color: blue,
                      ),

                      SizedBox(height: 12),

                      _Evidence(
                        icon: Icons.terrain_outlined,
                        title: context.l10n.insLowElevation,
                        value: context.l10n.insYes,
                        color: orange,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // PRIMARY CTA
                SizedBox(
                  height: 58,
                  child: FilledButton(
                    onPressed: () {
                      context.push(RoutePaths.satelliteAnalysis);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: bg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.satellite_alt_rounded),
                        SizedBox(width: 9),
                        Text(
                          context.l10n.insOpenSatellite,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 7),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
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

// ======================================================
// METRIC
// ======================================================

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: FieldInsightsScreen.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FieldInsightsScreen.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(
              color: FieldInsightsScreen.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: FieldInsightsScreen.muted,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// EVIDENCE
// ======================================================

class _Evidence extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _Evidence({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: FieldInsightsScreen.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ======================================================
// PILL
// ======================================================

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FieldInsightsScreen.green.withOpacity(.10),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: FieldInsightsScreen.green.withOpacity(.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FieldInsightsScreen.green, size: 13),

          const SizedBox(width: 5),

          Text(
            text,
            style: const TextStyle(
              color: FieldInsightsScreen.green,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// BACK BUTTON
// ======================================================

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: FieldInsightsScreen.card,
          shape: BoxShape.circle,
          border: Border.all(color: FieldInsightsScreen.line),
        ),
        child: Icon(icon, color: FieldInsightsScreen.text, size: 18),
      ),
    );
  }
}

// ======================================================
// PREMIUM TREND CHART
// ======================================================

class _TrendPainter extends CustomPainter {
  const _TrendPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // horizontal grid
    final grid = Paint()
      ..color = FieldInsightsScreen.line.withOpacity(.6)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final points = [
      Offset(0, size.height * .73),
      Offset(size.width * .17, size.height * .62),
      Offset(size.width * .33, size.height * .67),
      Offset(size.width * .50, size.height * .48),
      Offset(size.width * .67, size.height * .42),
      Offset(size.width * .84, size.height * .30),
      Offset(size.width, size.height * .21),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];

      final midX = (previous.dx + current.dx) / 2;

      linePath.cubicTo(
        midX,
        previous.dy,
        midX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    // AREA
    final area = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          FieldInsightsScreen.green.withOpacity(.30),
          FieldInsightsScreen.green.withOpacity(.01),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(area, areaPaint);

    // LINE
    final graphPaint = Paint()
      ..color = FieldInsightsScreen.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, graphPaint);

    // LAST POINT
    final last = points.last;

    canvas.drawCircle(
      last,
      9,
      Paint()..color = FieldInsightsScreen.green.withOpacity(.18),
    );

    canvas.drawCircle(last, 4.5, Paint()..color = FieldInsightsScreen.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
