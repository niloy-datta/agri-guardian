import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../core/localization/app_localizations.dart';
import '../shared/demo/showcase_story.dart';

/// The Home tab's dashboard content - the root screen of the Home branch
/// under `MainShell`'s persistent bottom nav (`lib/app/main_shell.dart`).
/// Extracted from the former `HomeScreen` (which used to own the bottom
/// nav bar and an internal `IndexedStack` itself); cross-tab navigation
/// now goes through go_router (`context.go`/`context.push`) instead of
/// local `setState`, so the same tap targets work correctly no matter
/// which shell branch is currently active.
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static const bg = Color(0xFF050C09);
  static const card = Color(0xFF0B1713);
  static const cardBorder = Color(0xFF163226);
  static const line = Color(0xFF132A20);

  static const green = Color(0xFF22E57F);
  static const mint = Color(0xFF2CEAA3);
  static const blue = Color(0xFF38BDF8);
  static const orange = Color(0xFFFFB020);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF829B90);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildTopBar(context),
                const SizedBox(height: 14),
                _buildHeroBanner(context),
                const SizedBox(height: 14),
                _buildWeatherMetricsRow(context),
                const SizedBox(height: 22),
                _buildMyFieldsSection(context),
                const SizedBox(height: 22),
                _buildQuickActionsSection(context),
                const SizedBox(height: 20),
                _buildPromoBanner(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= 1. TOP BAR =================
  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        // Brand logo (Stylized dual leaves)
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: green.withValues(alpha: 0.35)),
          ),
          child: const Center(
            child: Icon(Icons.eco_rounded, color: green, size: 22),
          ),
        ),
        const SizedBox(width: 10),

        // Brand Text & Slogan
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AgriLume',
                style: TextStyle(
                  color: text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 1),
              Text(
                AppLocalizations.of(context).brandTagline,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Notification Bell with Red Badge Dot '1'
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: card,
                shape: BoxShape.circle,
                border: Border.all(color: line),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: text,
                size: 20,
              ),
            ),
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4B4B),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 10),

        // Circular Profile Avatar with Generated Seedling Image
        GestureDetector(
          onTap: () => context.go(RoutePaths.profile),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: green.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/runtime/plant_avatar.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0F261C),
                  child: const Center(
                    child: Icon(Icons.spa_rounded, color: green, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= 2. HERO LANDSCAPE BANNER =================
  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      height: 270,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF091712),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cardBorder),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Generated high-res sunrise paddy landscape
          Image.asset(
            'assets/images/runtime/hero_rice_field.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.65),
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF133827),
                    Color(0xFF0D251A),
                    Color(0xFF06130D),
                  ],
                ),
              ),
            ),
          ),

          // Dark vignette overlays so text and search bar are perfectly readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),

          // Content inside Hero Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Your Farm,"
                Text(
                  AppLocalizations.of(context).heroTitleLead,
                  style: TextStyle(
                    color: text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),

                // "Our Intelligence"
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: AppLocalizations.of(context).heroAccentLead,
                        style: TextStyle(
                          color: text,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: AppLocalizations.of(context).heroAccentWord,
                        style: TextStyle(
                          color: mint,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: mint.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Subtitle
                Text(
                  AppLocalizations.of(context).heroSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),

                const Spacer(),

                // Search Bar + Calligraphy flourish
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF081510)
                              .withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: muted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context).searchFieldHint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push(RoutePaths.scan),
                              child: const Icon(
                                Icons.crop_free_rounded,
                                color: mint,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // "Healthy Fields Brighter Futures" calligraphy script
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context).healthyFieldsTagline,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFE8F5E9),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            AppLocalizations.of(context).brighterFuturesTagline,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFD4E157),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
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
    );
  }

  // ================= 3. WEATHER / CROP STATUS METRICS ROW =================
  Widget _buildWeatherMetricsRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        // 1. Weather: 28°C Partly Cloudy
        Expanded(
          child: _MetricPill(
            iconWidget: SizedBox(
              width: 20,
              height: 17,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    top: -1,
                    left: 0,
                    child: Icon(
                      Icons.wb_sunny_rounded,
                      color: orange,
                      size: 13,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(
                      Icons.cloud_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
            value: '${DemoStory.weatherNow.temperatureC.round()}°C',
            label: l10n.isBangla
                ? DemoStory.weatherNow.conditionBn
                : DemoStory.weatherNow.conditionEn,
          ),
        ),
        const SizedBox(width: 8),

        // 2. Humidity - same demo "now" as the Weather Risk Center.
        Expanded(
          child: _MetricPill(
            iconWidget: const Icon(
              Icons.water_drop_rounded,
              color: blue,
              size: 17,
            ),
            value: '${DemoStory.weatherNow.humidityPercent}%',
            label: l10n.humidityLabel,
          ),
        ),
        const SizedBox(width: 8),

        // 3. Crop Condition: Good Crop Condition
        Expanded(
          child: _MetricPill(
            iconWidget: Icon(Icons.eco_rounded, color: green, size: 17),
            value: l10n.cropConditionGood,
            label: l10n.cropConditionLabel,
          ),
        ),
      ],
    );
  }

  // ================= 4. "MY FIELDS" SECTION =================
  Widget _buildMyFieldsSection(BuildContext context) {
    const selectedFieldCardIndex = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).myFields,
              style: TextStyle(
                color: text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            GestureDetector(
              onTap: () => context.go(RoutePaths.fields),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context).seeAll,
                    style: TextStyle(
                      color: muted.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: muted,
                    size: 11,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Field Card Carousel Item
        GestureDetector(
          onTap: () => context.push(RoutePaths.satelliteAnalysis),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                // Generated Satellite Map Thumbnail with Polygon and Pin
                Container(
                  width: 112,
                  height: 84,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: green.withValues(alpha: 0.35)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/runtime/satellite_field.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF091E16),
                          child: const Icon(
                            Icons.map_rounded,
                            color: green,
                            size: 30,
                          ),
                        ),
                      ),
                      // Glowing Polygon overlay
                      CustomPaint(
                        painter: _SmallFieldPolygonPainter(color: green),
                      ),
                      // Center Location Pin
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Field Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.eco_rounded, color: green, size: 15),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).isBangla
                                  ? DemoStory.field.nameBn
                                  : DemoStory.field.nameEn,
                              style: TextStyle(
                                color: text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.of(context).isBangla
                            ? '${DemoStory.crop.cropBn}  •  ${DemoStory.field.areaBn}'
                            : '${DemoStory.crop.cropEn}  •  ${DemoStory.field.areaEn}',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Status Pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: green.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppLocalizations.of(context).healthyStatus,
                                  style: TextStyle(
                                    color: green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // No real sync time exists for this showcase card.
                      Text(
                        AppLocalizations.of(context).demoFieldLabel,
                        style: TextStyle(color: muted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),

                // Chevron Button
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: line,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: text,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Carousel Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isSelected = index == selectedFieldCardIndex;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: isSelected ? 18 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? mint : muted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ================= 5. "QUICK ACTIONS" SECTION =================
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).quickActions,
          style: TextStyle(
            color: text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Card 1: Scan Plant (Selected with green neon glow border)
            Expanded(
              child: _QuickActionItem(
                icon: Icons.camera_alt_rounded,
                title: AppLocalizations.of(context).scanPlantTitle,
                subtitle: AppLocalizations.of(context).scanPlantSubtitle,
                isHighlighted: true,
                onTap: () => context.push(RoutePaths.scan),
              ),
            ),
            const SizedBox(width: 8),

            // Card 2: Weather
            Expanded(
              child: _QuickActionItem(
                icon: Icons.cloud_outlined,
                title: AppLocalizations.of(context).weatherTitle,
                subtitle: AppLocalizations.of(context).weatherSubtitle,
                isHighlighted: false,
                onTap: () => context.push(RoutePaths.weather),
              ),
            ),
            const SizedBox(width: 8),

            // Card 3: Market Price
            Expanded(
              child: _QuickActionItem(
                icon: Icons.bar_chart_rounded,
                title: AppLocalizations.of(context).marketPriceTitle,
                subtitle: AppLocalizations.of(context).marketPriceSubtitle,
                isHighlighted: false,
                onTap: () => context.push(RoutePaths.marketPrice),
              ),
            ),
            const SizedBox(width: 8),

            // Card 4: Expert Help
            Expanded(
              child: _QuickActionItem(
                icon: Icons.menu_book_rounded,
                title: AppLocalizations.of(context).expertHelpTitle,
                subtitle: AppLocalizations.of(context).expertHelpSubtitle,
                isHighlighted: false,
                onTap: () => context.push(RoutePaths.aiAssistant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================= 6. PROMO / INSIGHTS BANNER =================
  Widget _buildPromoBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(RoutePaths.fieldInsights),
      child: Container(
        height: 94,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorder),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2B1F), Color(0xFF0B1F17), Color(0xFF071410)],
          ),
        ),
        child: Row(
          children: [
            // Photorealistic Generated Seedling in Soil Thumbnail
            Container(
              width: 72,
              height: 72,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: green.withValues(alpha: 0.35)),
              ),
              child: Image.asset(
                'assets/images/runtime/seedling_sprout.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0E271D),
                  child: const Icon(Icons.eco_rounded, color: green, size: 32),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Titles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context).promoTitle,
                    style: TextStyle(
                      color: text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    AppLocalizations.of(context).promoSubtitle,
                    style: TextStyle(
                      color: muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow circle button
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF132A20),
                shape: BoxShape.circle,
                border: Border.all(color: green.withValues(alpha: 0.35)),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: green,
                size: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= HELPER WIDGETS =================

class _MetricPill extends StatelessWidget {
  final Widget iconWidget;
  final String value;
  final String label;

  const _MetricPill({
    required this.iconWidget,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1713),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF163226)),
      ),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFF5FFF8),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF829B90),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
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

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22E57F);
    const card = Color(0xFF0B1713);
    const line = Color(0xFF163226);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFF0A2218) : card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighlighted ? green : line,
            width: isHighlighted ? 1.5 : 1,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: green.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isHighlighted ? green : const Color(0xFFF5FFF8),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF5FFF8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF829B90),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallFieldPolygonPainter extends CustomPainter {
  final Color color;

  _SmallFieldPolygonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.22)
      ..lineTo(size.width * 0.76, size.height * 0.16)
      ..lineTo(size.width * 0.88, size.height * 0.70)
      ..lineTo(size.width * 0.38, size.height * 0.86)
      ..lineTo(size.width * 0.12, size.height * 0.60)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
