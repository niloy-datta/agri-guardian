import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../domain/weather_risk_models.dart';

/// Palette and helpers matching Home's dark-green language
/// (`HomeDashboardScreen`'s bg/card/border/green/mint constants).
abstract final class WeatherTheme {
  static const bg = Color(0xFF050C09);
  static const card = Color(0xFF0B1713);
  static const cardRaised = Color(0xFF0E1D17);
  static const border = Color(0xFF163226);
  static const line = Color(0xFF132A20);

  static const green = Color(0xFF22E57F);
  static const mint = Color(0xFF2CEAA3);
  static const blue = Color(0xFF38BDF8);
  static const amber = Color(0xFFFFB020);
  static const orange = Color(0xFFFF8A3D);
  static const red = Color(0xFFFF5A5A);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF829B90);

  static const radius = 22.0;

  static BoxDecoration cardDecoration({Color? glow}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cardRaised, card],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glow?.withValues(alpha: 0.35) ?? border),
      boxShadow: [
        if (glow != null)
          BoxShadow(
            color: glow.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
      ],
    );
  }

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

extension WeatherRiskLevelUi on WeatherRiskLevel {
  /// Display name in the active language.
  String label(AppLocalizations l10n) => switch (this) {
    WeatherRiskLevel.low => l10n.riskLow,
    WeatherRiskLevel.moderate => l10n.riskModerate,
    WeatherRiskLevel.high => l10n.riskHigh,
    WeatherRiskLevel.severe => l10n.riskSevere,
  };

  Color get color => switch (this) {
    WeatherRiskLevel.low => WeatherTheme.green,
    WeatherRiskLevel.moderate => WeatherTheme.amber,
    WeatherRiskLevel.high => WeatherTheme.orange,
    WeatherRiskLevel.severe => WeatherTheme.red,
  };

  /// 0..1 fill for risk meters.
  double get fraction => (index + 1) / WeatherRiskLevel.values.length;
}

extension WeatherConditionUi on WeatherConditionKind {
  IconData get icon => switch (this) {
    WeatherConditionKind.sunny => Icons.wb_sunny_rounded,
    WeatherConditionKind.partlyCloudy => Icons.wb_cloudy_rounded,
    WeatherConditionKind.cloudy => Icons.cloud_rounded,
    WeatherConditionKind.rain => Icons.water_drop_rounded,
    WeatherConditionKind.thunderstorm => Icons.thunderstorm_rounded,
  };

  Color get tint => switch (this) {
    WeatherConditionKind.sunny => WeatherTheme.amber,
    WeatherConditionKind.partlyCloudy => const Color(0xFFD7E6DE),
    WeatherConditionKind.cloudy => const Color(0xFFA9BDB3),
    WeatherConditionKind.rain => WeatherTheme.blue,
    WeatherConditionKind.thunderstorm => const Color(0xFFB69CFF),
  };
}

extension WeatherDataOriginUi on WeatherDataOrigin {
  /// Origin name in the active language (Live / Cached / Demo).
  String label(AppLocalizations l10n) => switch (this) {
    WeatherDataOrigin.live => l10n.originLive,
    WeatherDataOrigin.cached => l10n.originCached,
    WeatherDataOrigin.demo => l10n.originDemo,
  };

  Color get color => switch (this) {
    WeatherDataOrigin.live => WeatherTheme.green,
    WeatherDataOrigin.cached => WeatherTheme.blue,
    WeatherDataOrigin.demo => WeatherTheme.amber,
  };
}

/// Small uppercase-ish English secondary label used under Bangla titles.
class WeatherEnLabel extends StatelessWidget {
  final String text;
  const WeatherEnLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: WeatherTheme.muted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Section title in the active language only.
class WeatherSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const WeatherSectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: WeatherTheme.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Rounded pill with a leading dot, e.g. risk level or data origin.
class WeatherPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool dense;

  const WeatherPill({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 9.5 : 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + slight rise entrance, staggered by [index]. Renders the child
/// immediately when the platform requests reduced motion.
class WeatherReveal extends StatelessWidget {
  final int index;
  final Widget child;
  final double fromScale;

  const WeatherReveal({
    super.key,
    this.index = 0,
    this.fromScale = 1,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (WeatherTheme.reduceMotion(context)) return child;

    const stepMs = 70;
    const baseMs = 420;
    final totalMs = baseMs + index * stepMs;
    final start = (index * stepMs) / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) {
        final scale = fromScale + (1 - fromScale) * t;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

/// Tap target with a subtle press-scale feedback.
class WeatherPressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const WeatherPressable({super.key, required this.onTap, required this.child});

  @override
  State<WeatherPressable> createState() => _WeatherPressableState();
}

class _WeatherPressableState extends State<WeatherPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = WeatherTheme.reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduce ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
