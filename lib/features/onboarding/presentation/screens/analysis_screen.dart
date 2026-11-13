import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/onboarding_providers.dart';
import '../widgets/onboarding_scaffold.dart';

/// The short cinematic hand-off between setup and the dashboard.
///
/// It is a *transition*, not a computation: no satellite pass, model run
/// or figure is produced here, and the copy says so. It marks setup
/// complete and moves on.
class OnboardingAnalysisScreen extends ConsumerStatefulWidget {
  /// Overridable so tests do not wait out the real animation.
  final Duration duration;

  const OnboardingAnalysisScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2600),
  });

  @override
  ConsumerState<OnboardingAnalysisScreen> createState() =>
      _OnboardingAnalysisScreenState();
}

class _OnboardingAnalysisScreenState
    extends ConsumerState<OnboardingAnalysisScreen>
    with SingleTickerProviderStateMixin {
  // Step labels come from AppLocalizations.analysisSteps; the count is fixed.
  static const _stepCount = 4;

  late final AnimationController _sweep;
  Timer? _stepTimer;
  Timer? _doneTimer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    final perStep = widget.duration ~/ _stepCount;
    _stepTimer = Timer.periodic(perStep, (_) {
      if (!mounted) return;
      setState(() => _step = math.min(_step + 1, _stepCount - 1));
    });

    _doneTimer = Timer(widget.duration, _finish);
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).finish();
    if (mounted) context.go(RoutePaths.home);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OnboardingTheme.reduceMotion(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _doneTimer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: OnboardingTheme.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/runtime/02_farmer_valley.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: OnboardingTheme.bg),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  OnboardingTheme.bg.withValues(alpha: 0.72),
                  OnboardingTheme.bg.withValues(alpha: 0.86),
                  OnboardingTheme.bg.withValues(alpha: 0.97),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 120,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _sweep,
                            builder: (context, _) => CustomPaint(
                              painter: _ScanPainter(t: _sweep.value),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        l10n.preparingFarm,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: OnboardingTheme.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.preparingDashboardEyebrow,
                        style: TextStyle(
                          color: OnboardingTheme.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: OnboardingTheme.reduceMotion(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        child: Row(
                          key: ValueKey(_step),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: OnboardingTheme.mint,
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                l10n.analysisSteps[_step],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: OnboardingTheme.mint,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Stated plainly: this screen computes nothing.
                      Text(
                        l10n.analysisDemoNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A radar-style sweep over concentric field rings.
class _ScanPainter extends CustomPainter {
  final double t;

  _ScanPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      ring.color = OnboardingTheme.mint.withValues(alpha: 0.10 + i * 0.04);
      canvas.drawCircle(c, r * (i / 3), ring);
    }

    final angle = t * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      angle,
      math.pi / 2,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: angle,
          endAngle: angle + math.pi / 2,
          colors: [
            OnboardingTheme.green.withValues(alpha: 0),
            OnboardingTheme.green.withValues(alpha: 0.28),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(c, 7, Paint()..color = OnboardingTheme.green);
    canvas.drawCircle(
      c,
      16,
      Paint()..color = OnboardingTheme.green.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t;
}
