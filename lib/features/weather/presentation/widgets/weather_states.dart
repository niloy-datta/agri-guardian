import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/weather_risk_models.dart';
import 'weather_theme.dart';

/// Banner explaining where the data on screen came from. Shown for
/// [WeatherDataOrigin.demo] and [WeatherDataOrigin.cached]; live data
/// needs no banner beyond the header chip.
class WeatherOriginBanner extends StatelessWidget {
  final WeatherDataOrigin origin;
  final DateTime? retrievedAt;

  const WeatherOriginBanner({
    super.key,
    required this.origin,
    required this.retrievedAt,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (origin) {
      WeatherDataOrigin.demo => _Banner(
        key: const ValueKey('weather-demo-banner'),
        icon: Icons.science_outlined,
        color: WeatherTheme.amber,
        title: l10n.demoBannerTitle,
        body: l10n.demoBannerBody,
      ),
      WeatherDataOrigin.cached => _Banner(
        key: const ValueKey('weather-cached-banner'),
        icon: Icons.history_rounded,
        color: WeatherTheme.blue,
        title: l10n.cachedBannerTitle,
        body: retrievedAt == null
            ? l10n.cachedBannerBodyUnknown
            : l10n.cachedBannerBodyDated(
                l10n.dayMonth(retrievedAt!.day, retrievedAt!.month),
              ),
      ),
      WeatherDataOrigin.live => const SizedBox.shrink(),
    };
  }
}

/// Offline notice. Wording depends on origin so demo values are never
/// described as data "fetched earlier".
class WeatherOfflineBanner extends StatelessWidget {
  final WeatherDataOrigin? origin;

  const WeatherOfflineBanner({super.key, required this.origin});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = switch (origin) {
      WeatherDataOrigin.demo => l10n.offlineDemo,
      WeatherDataOrigin.cached => l10n.offlineCached,
      WeatherDataOrigin.live => l10n.offlineLive,
      null => l10n.offlineNone,
    };
    return _Banner(
      key: const ValueKey('weather-offline-banner'),
      icon: Icons.wifi_off_rounded,
      color: WeatherTheme.red,
      title: l10n.offlineTitle,
      body: body,
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Banner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    height: 1.4,
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

/// Pulsing placeholder blocks shaped like the loaded layout.
class WeatherLoadingSkeleton extends StatefulWidget {
  const WeatherLoadingSkeleton({super.key});

  @override
  State<WeatherLoadingSkeleton> createState() => _WeatherLoadingSkeletonState();
}

class _WeatherLoadingSkeletonState extends State<WeatherLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WeatherTheme.reduceMotion(context)) {
      _c.value = 0.5;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.weatherLoading,
      child: AnimatedBuilder(
        key: const ValueKey('weather-loading'),
        animation: _c,
        builder: (context, _) {
          final a = 0.45 + 0.35 * _c.value;
          Widget block(double h, {double r = WeatherTheme.radius}) => Opacity(
            opacity: a,
            child: Container(
              height: h,
              decoration: BoxDecoration(
                color: WeatherTheme.card,
                borderRadius: BorderRadius.circular(r),
                border: Border.all(color: WeatherTheme.border),
              ),
            ),
          );
          return Column(
            children: [
              block(250, r: 26),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: block(112)),
                  const SizedBox(width: 8),
                  Expanded(child: block(112)),
                  const SizedBox(width: 8),
                  Expanded(child: block(112)),
                ],
              ),
              const SizedBox(height: 20),
              block(330),
            ],
          );
        },
      ),
    );
  }
}

class WeatherErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const WeatherErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('weather-error'),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      decoration: WeatherTheme.cardDecoration(glow: WeatherTheme.red),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: WeatherTheme.red.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: WeatherTheme.red,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.weatherLoadFailed,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WeatherTheme.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.weatherRetryHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: WeatherTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          WeatherPressable(
            onTap: onRetry,
            child: Container(
              key: const ValueKey('weather-retry'),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: WeatherTheme.green,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: WeatherTheme.green.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                  SizedBox(width: 6),
                  Text(
                    context.l10n.retry,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
