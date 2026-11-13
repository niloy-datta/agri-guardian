import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/assistant_models.dart';
import 'assistant_theme.dart';

/// Mixin for widgets driven by one repeating ambient controller that
/// stops (and holds a still frame) under reduced motion.
mixin _AmbientMotion<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController ambient = AnimationController(
    vsync: this,
    duration: ambientPeriod,
  );

  Duration get ambientPeriod;

  bool get wantsMotion => true;

  void syncMotion() {
    if (AssistantTheme.reduceMotion(context) || !wantsMotion) {
      ambient.stop();
      ambient.value = 0.25;
    } else if (!ambient.isAnimating) {
      ambient.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncMotion();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncMotion();
  }

  @override
  void dispose() {
    ambient.dispose();
    super.dispose();
  }
}

// ============================================================
// Intelligence orb
// ============================================================

/// Glowing core with field-contour rings and an orbiting "satellite";
/// its tempo and tint follow [phase].
class AssistantOrb extends StatefulWidget {
  final AssistantPhase phase;
  final double size;

  const AssistantOrb({super.key, required this.phase, this.size = 132});

  @override
  State<AssistantOrb> createState() => _AssistantOrbState();
}

class _AssistantOrbState extends State<AssistantOrb>
    with SingleTickerProviderStateMixin, _AmbientMotion {
  @override
  Duration get ambientPeriod => const Duration(seconds: 8);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI সহকারী · ${widget.phase.statusBn}',
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: ambient,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(t: ambient.value, phase: widget.phase),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final AssistantPhase phase;

  _OrbPainter({required this.t, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final tint = phase.color;
    final phaseAngle = t * 2 * math.pi;

    // Tempo: listening breathes faster, processing sweeps.
    final beats = switch (phase) {
      AssistantPhase.listening => 4,
      AssistantPhase.processing => 3,
      _ => 1,
    };
    final breathe = 0.5 + 0.5 * math.sin(phaseAngle * beats);

    // Outer halo.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            tint.withValues(alpha: 0.20 + 0.08 * breathe),
            tint.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Field-contour rings (slightly flattened, like terraced plots).
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final rr = r * (0.52 + i * 0.14);
      ring.color = tint.withValues(alpha: 0.22 - i * 0.05);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: rr * 2, height: rr * 1.7),
        ring,
      );
    }

    // Processing sweep arc.
    if (phase == AssistantPhase.processing) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.8),
        phaseAngle * 2,
        math.pi * 0.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [tint.withValues(alpha: 0), tint],
          ).createShader(Rect.fromCircle(center: c, radius: r * 0.8)),
      );
    }

    // Orbiting satellite dot on a tilted ellipse.
    final orbit = Offset(
      c.dx + r * 0.80 * math.cos(phaseAngle),
      c.dy + r * 0.36 * math.sin(phaseAngle),
    );
    canvas.drawCircle(
      orbit,
      3.2,
      Paint()..color = AssistantTheme.text.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      orbit,
      7,
      Paint()..color = tint.withValues(alpha: 0.22),
    );

    // Core.
    final coreR = r * (0.34 + 0.03 * breathe);
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Color.lerp(tint, Colors.white, 0.55)!,
            tint,
            const Color(0xFF0A3A28),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.phase != phase;
}

// ============================================================
// Microphone control
// ============================================================

class AssistantMicButton extends StatefulWidget {
  final AssistantPhase phase;
  final VoidCallback? onTap;

  const AssistantMicButton({super.key, required this.phase, this.onTap});

  @override
  State<AssistantMicButton> createState() => _AssistantMicButtonState();
}

class _AssistantMicButtonState extends State<AssistantMicButton>
    with SingleTickerProviderStateMixin, _AmbientMotion {
  @override
  Duration get ambientPeriod => const Duration(milliseconds: 1600);

  @override
  bool get wantsMotion => widget.phase == AssistantPhase.listening;

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final listening = phase == AssistantPhase.listening;
    final color = phase == AssistantPhase.error
        ? AssistantTheme.mint
        : phase.color;

    return AssistantPressable(
      key: const ValueKey('assistant-mic'),
      onTap: widget.onTap,
      semanticLabel: listening ? 'শোনা হচ্ছে' : 'মাইক চাপুন',
      child: SizedBox.square(
        dimension: 64,
        child: AnimatedBuilder(
          animation: ambient,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (listening && ambient.isAnimating)
                for (final offset in const [0.0, 0.5])
                  _ripple(color, (ambient.value + offset) % 1),
              child!,
            ],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: listening
                    ? [AssistantTheme.green, AssistantTheme.mint]
                    : [const Color(0xFF0F2A1F), const Color(0xFF081811)],
              ),
              border: Border.all(color: color, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: listening ? 0.45 : 0.25),
                  blurRadius: listening ? 22 : 14,
                  spreadRadius: listening ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: listening ? Colors.black : color,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ripple(Color color, double v) {
    final d = 58 + 30 * v;
    return IgnorePointer(
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.55 * (1 - v)),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Equalizer
// ============================================================

/// Five-bar level meter: animated while listening/processing, a calm
/// resting shape otherwise. Purely decorative - it does not reflect a
/// real audio level.
class AssistantEqualizer extends StatefulWidget {
  final AssistantPhase phase;

  const AssistantEqualizer({super.key, required this.phase});

  @override
  State<AssistantEqualizer> createState() => _AssistantEqualizerState();
}

class _AssistantEqualizerState extends State<AssistantEqualizer>
    with SingleTickerProviderStateMixin, _AmbientMotion {
  @override
  Duration get ambientPeriod => const Duration(milliseconds: 1200);

  @override
  bool get wantsMotion =>
      widget.phase == AssistantPhase.listening ||
      widget.phase == AssistantPhase.processing;

  static const _rest = [0.30, 0.55, 0.80, 0.55, 0.30];

  @override
  Widget build(BuildContext context) {
    final color = widget.phase.color;
    return ExcludeSemantics(
      child: SizedBox(
        width: 30,
        height: 16,
        child: AnimatedBuilder(
          animation: ambient,
          builder: (context, _) {
            final moving = ambient.isAnimating;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 3,
                    height:
                        16 *
                        (moving
                            ? 0.25 +
                                  0.75 *
                                      (0.5 +
                                          0.5 *
                                              math.sin(
                                                ambient.value * 2 * math.pi * 2 +
                                                    i * 1.3,
                                              ))
                            : _rest[i] * 0.6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: moving ? 1 : 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
