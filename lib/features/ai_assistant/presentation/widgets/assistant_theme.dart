import 'package:flutter/material.dart';

import '../../domain/assistant_models.dart';

/// Palette matching Home's dark-green language
/// (`HomeDashboardScreen`'s bg/card/border/green/mint constants).
abstract final class AssistantTheme {
  static const bg = Color(0xFF050C09);
  static const card = Color(0xFF0B1713);
  static const cardRaised = Color(0xFF0E1D17);
  static const border = Color(0xFF163226);
  static const line = Color(0xFF132A20);

  static const green = Color(0xFF22E57F);
  static const mint = Color(0xFF2CEAA3);
  static const blue = Color(0xFF38BDF8);
  static const amber = Color(0xFFFFB020);
  static const red = Color(0xFFFF5A5A);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF829B90);

  static const radius = 22.0;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String bnDigits(Object value) => value.toString().replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => _bnDigits[int.parse(m[0]!)],
);

String bnClock(DateTime t) =>
    bnDigits('${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}');

extension AssistantPhaseUi on AssistantPhase {
  String get statusBn => switch (this) {
    AssistantPhase.idle => 'প্রশ্ন করতে মাইক চাপুন বা লিখুন',
    AssistantPhase.listening => 'শুনছি… বলুন',
    AssistantPhase.processing => 'ভাবছি…',
    AssistantPhase.answering => 'উত্তর প্রস্তুত · আরও জিজ্ঞেস করুন',
    AssistantPhase.error => 'সমস্যা হয়েছে',
  };

  Color get color => switch (this) {
    AssistantPhase.idle => AssistantTheme.mint,
    AssistantPhase.listening => AssistantTheme.green,
    AssistantPhase.processing => AssistantTheme.blue,
    AssistantPhase.answering => AssistantTheme.mint,
    AssistantPhase.error => AssistantTheme.red,
  };
}

extension AnswerOriginUi on AnswerOrigin {
  String get labelBn => switch (this) {
    AnswerOrigin.live => 'লাইভ উত্তর',
    AnswerOrigin.demo => 'ডেমো উত্তর · যাচাই করা নয়',
    AnswerOrigin.notConnected => 'লাইভ সহকারী সংযুক্ত নয়',
  };

  Color get color => switch (this) {
    AnswerOrigin.live => AssistantTheme.green,
    AnswerOrigin.demo => AssistantTheme.amber,
    AnswerOrigin.notConnected => AssistantTheme.muted,
  };
}

extension EvidenceKindUi on EvidenceKind {
  IconData get icon => switch (this) {
    EvidenceKind.connected => Icons.check_circle_rounded,
    EvidenceKind.demo => Icons.science_outlined,
    EvidenceKind.notConnected => Icons.link_off_rounded,
  };

  Color get color => switch (this) {
    EvidenceKind.connected => AssistantTheme.green,
    EvidenceKind.demo => AssistantTheme.amber,
    EvidenceKind.notConnected => AssistantTheme.muted,
  };
}

extension AssistantDestinationUi on AssistantDestination {
  IconData get icon => switch (this) {
    AssistantDestination.scan => Icons.camera_alt_rounded,
    AssistantDestination.weather => Icons.cloud_outlined,
    AssistantDestination.fields => Icons.eco_outlined,
    AssistantDestination.market => Icons.bar_chart_rounded,
  };
}

class AssistantEnLabel extends StatelessWidget {
  final String text;
  const AssistantEnLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AssistantTheme.muted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

class AssistantPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AssistantPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 11)
          else
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
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + rise entrance; instant under reduced motion.
class AssistantReveal extends StatelessWidget {
  final Widget child;
  final int index;

  const AssistantReveal({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AssistantTheme.reduceMotion(context)) return child;
    const stepMs = 70;
    final totalMs = 380 + index * stepMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(index * stepMs / totalMs, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
    );
  }
}

/// Tap target with press-scale feedback and a minimum 44px hit area.
class AssistantPressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;

  const AssistantPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  @override
  State<AssistantPressable> createState() => _AssistantPressableState();
}

class _AssistantPressableState extends State<AssistantPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AssistantTheme.reduceMotion(context);
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: AnimatedScale(
            scale: _pressed && !reduce ? 0.95 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.45,
              duration: const Duration(milliseconds: 150),
              child: Center(widthFactor: 1, heightFactor: 1, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
