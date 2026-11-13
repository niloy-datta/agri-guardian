import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Palette matching Home's dark-green language
/// (`HomeDashboardScreen`'s bg/card/border/green/mint constants).
abstract final class OnboardingTheme {
  static const bg = Color(0xFF050C09);
  static const card = Color(0xFF0B1713);
  static const cardRaised = Color(0xFF0E1D17);
  static const border = Color(0xFF163226);
  static const line = Color(0xFF132A20);

  static const green = Color(0xFF22E57F);
  static const mint = Color(0xFF2CEAA3);
  static const blue = Color(0xFF38BDF8);
  static const amber = Color(0xFFFFB020);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF829B90);

  static const radius = 20.0;

  /// The five setup steps after the splash.
  static const totalSteps = 5;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Shared chrome for every setup step: step counter, progress bar,
/// Bangla title with a small English subtitle, scrolling content, and a
/// pinned primary action.
class OnboardingScaffold extends StatelessWidget {
  final int step;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  final String primaryLabel;

  /// Null disables the primary action (the step is not answered yet).
  final VoidCallback? onPrimary;

  final VoidCallback? onBack;

  /// Optional secondary action, e.g. "skip this step".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingTheme.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _StepHeader(step: step, onBack: onBack),
                ),
                Expanded(
                  child: ListView(
                    // Keep the short setup forms mounted so accessibility,
                    // widget tests, and ensureVisible can reach every choice
                    // even when it starts below the fold.
                    cacheExtent: 1000,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: OnboardingTheme.text,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (subtitle case final subtitleText?) ...[
                        const SizedBox(height: 12),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      ...children,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: OnboardingTheme.green,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: OnboardingTheme.card,
                            disabledForegroundColor: OnboardingTheme.muted,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            primaryLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      if (secondaryLabel != null)
                        TextButton(
                          onPressed: onSecondary,
                          style: TextButton.styleFrom(
                            foregroundColor: OnboardingTheme.muted,
                          ),
                          child: Text(
                            secondaryLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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

class _StepHeader extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;

  const _StepHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        if (onBack != null)
          _RoundButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack!,
            semanticLabel: l10n.previousStep,
          )
        else
          const SizedBox(width: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.stepOf(step, OnboardingTheme.totalSteps),
                style: const TextStyle(
                  color: OnboardingTheme.mint,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: OnboardingTheme.line),
                      AnimatedFractionallySizedBox(
                        duration: OnboardingTheme.reduceMotion(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        widthFactor: step / OnboardingTheme.totalSteps,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                OnboardingTheme.green,
                                OnboardingTheme.mint,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: OnboardingTheme.card,
            shape: BoxShape.circle,
            border: Border.all(color: OnboardingTheme.line),
          ),
          child: Icon(icon, color: OnboardingTheme.text, size: 19),
        ),
      ),
    );
  }
}

/// A large tappable choice row used by the location, language, soil and
/// goal steps.
class OnboardingChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  const OnboardingChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? OnboardingTheme.green;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(OnboardingTheme.radius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: OnboardingTheme.reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : OnboardingTheme.card,
            borderRadius: BorderRadius.circular(OnboardingTheme.radius),
            border: Border.all(
              color: selected ? color : OnboardingTheme.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: OnboardingTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle case final subtitleText?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          color: OnboardingTheme.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: selected ? 1 : 0,
                child: Icon(Icons.check_circle_rounded, color: color, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark text field matching the onboarding surfaces.
class OnboardingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? suffix;
  final ValueChanged<String>? onChanged;

  const OnboardingTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: OnboardingTheme.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          cursorColor: OnboardingTheme.mint,
          style: const TextStyle(
            color: OnboardingTheme.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: OnboardingTheme.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: OnboardingTheme.mint, size: 19),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: OnboardingTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: OnboardingTheme.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: OnboardingTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: OnboardingTheme.green,
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
