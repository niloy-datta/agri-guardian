import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../shared/demo/showcase_story.dart';

class SatelliteMapScreen extends StatefulWidget {
  const SatelliteMapScreen({super.key});

  @override
  State<SatelliteMapScreen> createState() => _SatelliteMapScreenState();
}

class _SatelliteMapScreenState extends State<SatelliteMapScreen>
    with SingleTickerProviderStateMixin {
  int _activeLayer = 0; // 0 = NDVI, 1 = Moisture, 2 = Elevation
  late AnimationController _pulseController;

  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const blue = Color(0xFF4DA3FF);
  static const orange = Color(0xFFFFB020);
  static const red = Color(0xFFFF5555);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.satMyFieldTwin,
                              style: TextStyle(
                                color: text,
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              context.l10n.satFieldLine(context.l10n.isBangla ? DemoStory.field.nameBn : DemoStory.field.nameEn, context.l10n.isBangla ? DemoStory.crop.cropBn : DemoStory.crop.cropEn, context.l10n.isBangla ? DemoStory.field.areaBn : DemoStory.field.areaEn),
                              style: TextStyle(color: muted, fontSize: 11.5),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.satellite_alt_rounded,
                              color: green,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              context.l10n.satDemoImage(context.l10n.isBangla ? DemoStory.demoTagBn : DemoStory.demoTagEn),
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

                // ================= SCROLLABLE SATELLITE CONTENT =================
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                    children: [
                      // LAYER SELECTOR PILLS
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: line),
                        ),
                        child: Row(
                          children: [
                            _LayerTab(
                              title: context.l10n.satNdviHealth,
                              icon: Icons.eco_rounded,
                              selected: _activeLayer == 0,
                              color: green,
                              onTap: () => setState(() => _activeLayer = 0),
                            ),
                            _LayerTab(
                              title: context.l10n.satSoilMoisture,
                              icon: Icons.water_drop_rounded,
                              selected: _activeLayer == 1,
                              color: blue,
                              onTap: () => setState(() => _activeLayer = 1),
                            ),
                            _LayerTab(
                              title: context.l10n.satRiskLevel,
                              icon: Icons.warning_amber_rounded,
                              selected: _activeLayer == 2,
                              color: orange,
                              onTap: () => setState(() => _activeLayer = 2),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // SATELLITE MAP CONTAINER WITH OVERLAYS (Matches 05_land_digital_twin_satellite.jpg)
                      Container(
                        height: 330,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: line),
                          boxShadow: [
                            BoxShadow(
                              color: green.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Satellite Base Image
                            Image.asset(
                              'assets/images/runtime/05_land_digital_twin_satellite.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF091F16),
                                child: const Center(
                                  child: Icon(
                                    Icons.map_rounded,
                                    size: 100,
                                    color: green,
                                  ),
                                ),
                              ),
                            ),

                            // Map Grid & Coordinates Overlay
                            Positioned(
                              top: 12,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: const Text(
                                  'GPS: 24.4332° N, 90.7812° E',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),

                            // 2. Field Boundary Polygon Painter
                            CustomPaint(
                              painter: _FieldPolygonPainter(
                                color: _activeLayer == 0
                                    ? green
                                    : (_activeLayer == 1 ? blue : orange),
                              ),
                            ),

                            // 3. Hotspot Callout: "এই অংশে স্বাস্থ্য কম"
                            Positioned(
                              top: 130,
                              right: 32,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06110E)
                                          .withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: orange,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: orange.withOpacity(0.3),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.priority_high_rounded,
                                          color: orange,
                                          size: 13,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          context.l10n.satLowHealthZone,
                                          style: TextStyle(
                                            color: text,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Pulsing Beacon
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return Container(
                                        width:
                                            18 + (_pulseController.value * 12),
                                        height:
                                            18 + (_pulseController.value * 12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: orange.withOpacity(
                                            0.5 -
                                                (_pulseController.value * 0.35),
                                          ),
                                          border: Border.all(
                                            color: orange,
                                            width: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // Bottom Legend Bar
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _LegendItem(color: red, label: context.l10n.satLegendWeak),
                                    _LegendItem(color: orange, label: context.l10n.riskModerate),
                                    _LegendItem(color: green, label: context.l10n.satLegendHealthy),
                                    _LegendItem(
                                      color: Color(0xFF00FF7F),
                                      label: context.l10n.riskHigh,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // OVERALL HEALTH METRIC CARD (72% Health)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: line),
                        ),
                        child: Row(
                          children: [
                            // Circular Gauge 72%
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: 0.72,
                                    strokeWidth: 5,
                                    backgroundColor: line,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          green,
                                        ),
                                  ),
                                  Text(
                                    '${context.l10n.digits(72)}%',
                                    style: TextStyle(
                                      color: green,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.satHealthOverall,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    context.l10n.satDemoNoLivePass,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // DETECTED ISSUES SECTION
                      Text(
                        context.l10n.satAlertsTitle,
                        style: TextStyle(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _IssueCard(
                        title: context.l10n.satLeafBlastTitle,
                        desc: context.l10n.satLeafBlastDesc((context.l10n.isBangla ? DemoStory.issues.leafStressZoneBn : DemoStory.issues.leafStressZoneEn)),
                        badge: context.l10n.satAlertWarning,
                        badgeColor: orange,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(height: 8),

                      _IssueCard(
                        title: context.l10n.satWaterloggingTitle,
                        desc: context.l10n.satWaterloggingDesc((context.l10n.isBangla ? DemoStory.issues.waterloggingZoneBn : DemoStory.issues.waterloggingZoneEn)),
                        badge: context.l10n.satAlertInfo,
                        badgeColor: blue,
                        icon: Icons.water_drop_outlined,
                      ),
                      const SizedBox(height: 8),

                      _IssueCard(
                        title: context.l10n.satGrowthNormalTitle,
                        desc: context.l10n.satGrowthNormalDesc,
                        badge: context.l10n.satAlertSatisfactory,
                        badgeColor: green,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ],
                  ),
                ),

                // ================= BOTTOM STICKY AI SPOT SCAN BAR =================
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    color: card,
                    border: const Border(top: BorderSide(color: line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: orange.withOpacity(0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.satSpotScan,
                              style: TextStyle(
                                color: text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              context.l10n.satNorthDecline,
                              style: TextStyle(color: muted, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          context.push(RoutePaths.scan);
                        },
                        child: Text(
                          context.l10n.satScanNow,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

class _LayerTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _LayerTab({
    required this.title,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? color : const Color(0xFF8EA69A),
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: selected ? color : const Color(0xFF8EA69A),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9.5),
        ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  final String title;
  final String desc;
  final String badge;
  final Color badgeColor;
  final IconData icon;

  const _IssueCard({
    required this.title,
    required this.desc,
    required this.badge,
    required this.badgeColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1D18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D382F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: badgeColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF5FFF8),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeColor,
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
                    fontSize: 10.5,
                    height: 1.3,
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

class _FieldPolygonPainter extends CustomPainter {
  final Color color;

  _FieldPolygonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.22)
      ..lineTo(size.width * 0.72, size.height * 0.14)
      ..lineTo(size.width * 0.86, size.height * 0.68)
      ..lineTo(size.width * 0.38, size.height * 0.82)
      ..lineTo(size.width * 0.12, size.height * 0.58)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Vertices dots
    final vertexPaint = Paint()..color = Colors.white;
    final vertices = [
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.72, size.height * 0.14),
      Offset(size.width * 0.86, size.height * 0.68),
      Offset(size.width * 0.38, size.height * 0.82),
      Offset(size.width * 0.12, size.height * 0.58),
    ];
    for (var v in vertices) {
      canvas.drawCircle(v, 4.5, Paint()..color = color);
      canvas.drawCircle(v, 2.5, vertexPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
