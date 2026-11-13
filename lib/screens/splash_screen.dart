import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../features/onboarding/application/onboarding_providers.dart';

/// AgriLume launch splash screen.
///
/// Features the cinematic Earth intelligence artwork (space, satellite,
/// glowing leaf in orbital rings, and sunrise over green fields) with
/// clean, premium brand typography and a single "Get Started →" CTA.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF050C09);
  static const _green = Color(0xFF22E57F);
  static const _text = Color(0xFFF5FFF8);
  static const _muted = Color(0xFFBFD3C8);

  static const _heroImage = 'assets/images/runtime/hero_leaf_orbit.png';
  static const _autoAdvanceDuration = Duration(seconds: 4);

  late final AnimationController _motionController;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    // Subtle breathing drift for the artwork.
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    _autoAdvanceTimer = Timer(_autoAdvanceDuration, () {
      if (!mounted) return;
      unawaited(_continue());
    });
  }

  /// Leaves the splash for first-run onboarding setup, or straight to the dashboard
  /// once setup has been completed before.
  Future<void> _continue() async {
    _autoAdvanceTimer?.cancel();
    final completed = await ref.read(onboardingStoreProvider).isComplete();
    if (!mounted) return;
    context.go(
      completed ? RoutePaths.home : RoutePaths.onboardingLocation,
    );
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed cinematic artwork with subtle Ken Burns drift
          AnimatedBuilder(
            animation: _motionController,
            builder: (context, child) => Transform.scale(
              scale: 1.02 + (_motionController.value * 0.03),
              child: child,
            ),
            child: Image.asset(
              _heroImage,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0A1F16),
                      Color(0xFF071710),
                      _bg,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Legibility gradients: soft dark scrim at top for typography,
          // and bottom for CTA, keeping center glowing leaf fully clear.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _bg.withValues(alpha: 0.72),
                    _bg.withValues(alpha: 0.20),
                    Colors.transparent,
                    _bg.withValues(alpha: 0.40),
                    _bg.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.22, 0.50, 0.78, 1.0],
                ),
              ),
            ),
          ),

          // Content layout: Top copy, open center, bottom CTA
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _green.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.eco_rounded,
                          color: _green,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AgriLume',
                          style: TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Headline: "See Your Farm. Know What’s Next."
                  const Text(
                    'See Your Farm.\nKnow What’s Next.',
                    style: TextStyle(
                      color: _text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                      letterSpacing: -0.6,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 16,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sub-caption (ছোট করে): "Earth intelligence for smarter farming."
                  const Text(
                    'Earth intelligence for smarter farming.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                  // Central spacer leaves the glowing leaf & landscape clear
                  const Spacer(),

                  // Bottom: Single CTA button "Get Started →"
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => unawaited(_continue()),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: _bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 12,
                        shadowColor: _green.withValues(alpha: 0.45),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Get Started'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
