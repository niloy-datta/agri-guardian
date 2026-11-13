import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../core/localization/app_localizations.dart';
import '../shared/demo/showcase_story.dart';

class DiagnosisResultScreen extends StatelessWidget {
  final VoidCallback? onTreatment;

  const DiagnosisResultScreen({super.key, this.onTreatment});

  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const card2 = Color(0xFF10271E);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const greenLight = Color(0xFF38F28D);
  static const blue = Color(0xFF4DA3FF);
  static const orange = Color(0xFFFFB020);
  static const red = Color(0xFFFF5555);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                              l10n.diagResultTitle,
                              style: TextStyle(
                                color: text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              l10n.diagResultSubtitle,
                              style: TextStyle(color: muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      _CircleButton(
                        icon: Icons.bookmark_border_rounded,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.diagSaveUnavailable),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _CircleButton(
                        icon: Icons.share_outlined,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.diagShareUnavailable),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
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
                      // HERO CARD: Image + Disease Title + 92% Gauge + Risk
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: line),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF10281F),
                              Color(0xFF0C1E17),
                              Color(0xFF071410),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: green.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Captured leaf thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 90,
                                    height: 105,
                                    color: card2,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          'assets/images/runtime/06_disease_detection_result_dark.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Image.asset(
                                                'assets/images/runtime/08_plant_scan_camera_guide.png',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.eco_rounded,
                                                      color: green,
                                                      size: 40,
                                                    ),
                                              ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 3,
                                            ),
                                            color: Colors.black.withOpacity(
                                              0.65,
                                            ),
                                            child: Text(
                                              l10n.diagCapturedPhoto,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Disease info + 92% gauge
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: orange.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: orange.withOpacity(0.35),
                                          ),
                                        ),
                                        child: Text(
                                          l10n.diagUrgent,
                                          style: TextStyle(
                                            color: orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        l10n.isBangla
                                            ? DemoStory.diagnosis.nameBn
                                            : DemoStory.diagnosis.nameEn,
                                        style: TextStyle(
                                          color: text,
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        DemoStory.diagnosis.pathogen,
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // 92% Confidence badge
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                CircularProgressIndicator(
                                                  value: 0.92,
                                                  strokeWidth: 3.5,
                                                  backgroundColor: line
                                                      .withOpacity(0.5),
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                        Color
                                                      >(green),
                                                ),
                                                Text(
                                                  '${l10n.digits(92)}%',
                                                  style: TextStyle(
                                                    color: green,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  l10n.diagConfidenceBadge(92),
                                                  style: TextStyle(
                                                    color: green,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  l10n.diagHighReliability,
                                                  style: TextStyle(
                                                    color: muted,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(color: line, height: 1),
                            const SizedBox(height: 12),

                            // Stepped Risk Meter: নিম্ন -> মাঝারি -> উচ্চ
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  l10n.diagRiskLevelLabel,
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.diagRiskRange,
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                // 3 stepped bars
                                Row(
                                  children: [
                                    _RiskStepBar(
                                      color: green,
                                      active: true,
                                      label: l10n.diagLevelLow,
                                    ),
                                    const SizedBox(width: 4),
                                    _RiskStepBar(
                                      color: orange,
                                      active: true,
                                      label: l10n.diagLevelModerate,
                                    ),
                                    const SizedBox(width: 4),
                                    _RiskStepBar(
                                      color: red.withOpacity(0.3),
                                      active: false,
                                      label: l10n.diagLevelHigh,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // KEY METRICS ROW (Affected Area, Yield Risk, Spread Rate)
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              title: l10n.diagAffectedArea,
                              value: '~${l10n.digits(32)}%',
                              subtitle: l10n.diagLeafArea,
                              color: orange,
                              icon: Icons.pie_chart_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              title: l10n.diagYieldRisk,
                              value: l10n.diagLevelHigh,
                              subtitle: l10n.diagWithoutTreatment,
                              color: red,
                              icon: Icons.trending_down_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              title: l10n.diagSpreadSpeed,
                              value: l10n.diagFast,
                              subtitle: l10n.diagHumidWeather,
                              color: blue,
                              icon: Icons.speed_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // "আজ কী করবেন? (IMMEDIATE ACTIONS)"
                      Text(
                        l10n.diagTodayActions,
                        style: TextStyle(
                          color: text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _ActionStepCard(
                        number: l10n.digits('01'),
                        title: l10n.diagStep1Title,
                        desc: l10n.diagStep1Desc,
                        icon: Icons.do_not_disturb_on_rounded,
                        color: orange,
                      ),
                      const SizedBox(height: 8),

                      _ActionStepCard(
                        number: l10n.digits('02'),
                        title: l10n.diagStep2Title,
                        desc: l10n.diagStep2Desc,
                        icon: Icons.water_drop_outlined,
                        color: blue,
                      ),
                      const SizedBox(height: 8),

                      _ActionStepCard(
                        number: l10n.digits('03'),
                        title: l10n.diagStep3Title,
                        desc: l10n.diagStep3Desc,
                        icon: Icons.medical_services_outlined,
                        color: green,
                      ),

                      const SizedBox(height: 20),

                      // SIMILAR CASES COMPARISON (From 13_scan_result_similar_cases_comparison.png)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.diagSimilarCases,
                              style: TextStyle(
                                color: text,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.diagModelResult,
                            style: TextStyle(
                              color: green.withOpacity(0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        height: 94,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _SimilarCaseCard(
                              title: l10n.isBangla
                                  ? DemoStory.diagnosis.nameBn
                                  : DemoStory.diagnosis.nameEn,
                              percent: '${l10n.digits(92)}%',
                              selected: true,
                            ),
                            _SimilarCaseCard(
                              title: l10n.diagModelBrownSpot,
                              percent: '${l10n.digits(54)}%',
                              selected: false,
                            ),
                            _SimilarCaseCard(
                              title: l10n.diagModelLeafSmut,
                              percent: '${l10n.digits(36)}%',
                              selected: false,
                            ),
                            _SimilarCaseCard(
                              title: l10n.diagModelHealthyLeaf,
                              percent: '${l10n.digits(12)}%',
                              selected: false,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // EXPLANATION / GUIDELINES EXPANDABLE TILES
                      _ExpandableInfoTile(
                        icon: Icons.psychology_rounded,
                        title: l10n.diagWhyAiTitle,
                        subtitle: l10n.diagWhyAiSubtitle,
                        content: l10n.diagWhyAiContent,
                      ),
                      const SizedBox(height: 8),

                      _ExpandableInfoTile(
                        icon: Icons.wb_sunny_outlined,
                        title: l10n.diagWeatherSpreadTitle,
                        subtitle: l10n.diagWeatherSpreadSubtitle,
                        content: l10n.diagWeatherSpreadContent,
                      ),
                    ],
                  ),
                ),

                // ================= BOTTOM STICKY CTA =================
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  decoration: BoxDecoration(
                    color: card,
                    border: const Border(top: BorderSide(color: line)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed:
                          onTreatment ??
                          () {
                            context.push(RoutePaths.treatmentPlan);
                          },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.diagViewFullPlan,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
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

class _RiskStepBar extends StatelessWidget {
  final Color color;
  final bool active;
  final String label;

  const _RiskStepBar({
    required this.color,
    required this.active,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 8,
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFF1D382F),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1D18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D382F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF5FFF8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF8EA69A), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _ActionStepCard extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _ActionStepCard({
    required this.number,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF5FFF8),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
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

class _SimilarCaseCard extends StatelessWidget {
  final String title;
  final String percent;
  final bool selected;

  const _SimilarCaseCard({
    required this.title,
    required this.percent,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF20E27A);

    return Container(
      width: 115,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF10281F) : const Color(0xFF0D1D18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? green : const Color(0xFF1D382F),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            percent,
            style: TextStyle(
              color: selected ? green : const Color(0xFF8EA69A),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF5FFF8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableInfoTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String content;

  const _ExpandableInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.content,
  });

  @override
  State<_ExpandableInfoTile> createState() => _ExpandableInfoTileState();
}

class _ExpandableInfoTileState extends State<_ExpandableInfoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D1D18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF1D382F)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              widget.icon,
              color: const Color(0xFF20E27A),
              size: 22,
            ),
            title: Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFFF5FFF8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              widget.subtitle,
              style: const TextStyle(color: Color(0xFF8EA69A), fontSize: 10.5),
            ),
            trailing: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: const Color(0xFF8EA69A),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                widget.content,
                style: const TextStyle(
                  color: Color(0xFF8EA69A),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
