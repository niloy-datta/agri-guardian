import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/weather_risk_models.dart';
import 'weather_theme.dart';

/// Large current-conditions card: atmospheric gradient, drifting glow and
/// soft rain streaks, big temperature, and a three-stat footer.
class WeatherHeroCard extends StatefulWidget {
  final WeatherRiskSnapshot snapshot;

  const WeatherHeroCard({super.key, required this.snapshot});

  @override
  State<WeatherHeroCard> createState() => _WeatherHeroCardState();
}

class _WeatherHeroCardState extends State<WeatherHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WeatherTheme.reduceMotion(context)) {
      _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final current = s.current;

    return WeatherReveal(
      fromScale: 0.96,
      child: Container(
        key: const ValueKey('weather-hero'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: WeatherTheme.border),
          boxShadow: [
            BoxShadow(
              color: WeatherTheme.mint.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => CustomPaint(
                    painter: _AtmospherePainter(
                      t: _ambient.value,
                      rainy: s.rainfall.probabilityPercent24h >= 50,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: WeatherTheme.mint,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.fieldLabel.resolve(isBangla: context.l10n.isBangla),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      WeatherPill(
                        label: context.l10n.nowLabel,
                        color: WeatherTheme.mint,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                context.l10n.temperature(current.temperatureC),
                                style: TextStyle(
                                  color: WeatherTheme.text,
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -2,
                                  shadows: [
                                    Shadow(
                                      color: WeatherTheme.mint.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              current.conditionLabel.resolve(
                                isBangla: context.l10n.isBangla,
                              ),
                              style: const TextStyle(
                                color: WeatherTheme.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${context.l10n.feelsLikeLabel} ${context.l10n.temperature(current.feelsLikeC)}',
                              style: const TextStyle(
                                color: WeatherTheme.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ConditionOrb(condition: current.condition),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.umbrella_rounded,
                            color: WeatherTheme.blue,
                            value: '${context.l10n.digits(s.rainfall.probabilityPercent24h)}%',
                            label: context.l10n.rainChanceLabel,
                          ),
                        ),
                        _divider(),
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.water_drop_outlined,
                            color: WeatherTheme.mint,
                            value: '${context.l10n.digits(current.humidityPercent)}%',
                            label: context.l10n.humidityLabel,
                          ),
                        ),
                        _divider(),
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.shield_outlined,
                            color: s.rainfall.risk.color,
                            value: s.rainfall.risk.label(context.l10n),
                            label: context.l10n.riskShortLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 30,
    color: Colors.white.withValues(alpha: 0.08),
  );
}

class _ConditionOrb extends StatelessWidget {
  final WeatherConditionKind condition;
  const _ConditionOrb({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            condition.tint.withValues(alpha: 0.22),
            condition.tint.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Icon(condition.icon, color: condition.tint, size: 46),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _HeroStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: WeatherTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: WeatherTheme.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Deep green sky gradient, a slowly drifting mint glow, faint cloud
/// bands and (when rain is likely) thin diagonal rain streaks.
class _AtmospherePainter extends CustomPainter {
  final double t;
  final bool rainy;

  _AtmospherePainter({required this.t, required this.rainy});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12372A), Color(0xFF0A2019), Color(0xFF06120D)],
        ).createShader(rect),
    );

    final phase = t * 2 * math.pi;

    // Drifting glow.
    final glowCenter = Offset(
      size.width * (0.78 + 0.06 * math.sin(phase)),
      size.height * (0.22 + 0.05 * math.cos(phase)),
    );
    canvas.drawCircle(
      glowCenter,
      size.width * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            WeatherTheme.mint.withValues(alpha: 0.18),
            WeatherTheme.mint.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCenter, radius: size.width * 0.42),
        ),
    );

    // Soft cloud bands.
    final cloud = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    for (var i = 0; i < 3; i++) {
      final dx = ((t + i / 3) % 1) * (size.width + 160) - 80;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx, size.height * (0.18 + i * 0.16)),
          width: 150,
          height: 38,
        ),
        cloud,
      );
    }

    if (!rainy) return;

    // Rain streaks, deterministic positions.
    final rain = Paint()
      ..color = WeatherTheme.blue.withValues(alpha: 0.16)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const count = 22;
    for (var i = 0; i < count; i++) {
      final seed = (i * 73) % 100 / 100;
      final x = size.width * ((i + 0.5) / count);
      final y = ((seed + t * 3) % 1) * (size.height + 40) - 20;
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 14), rain);
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter old) =>
      old.t != t || old.rainy != rainy;
}
