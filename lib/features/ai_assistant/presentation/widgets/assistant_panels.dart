import 'package:flutter/material.dart';

import '../../../../shared/demo/showcase_story.dart';
import '../../domain/assistant_models.dart';
import 'assistant_orb.dart';
import 'assistant_theme.dart';

const assistantSuggestedQuestions = [
  'আজ সেচ দেব?',
  'এই পাতায় সমস্যা কী?',
  'বৃষ্টি হওয়ার সম্ভাবনা?',
  'কখন বিক্রি করা ভালো?',
  'আমার জমির অবস্থা কী?',
];

// ============================================================
// Hero
// ============================================================

class AssistantHero extends StatelessWidget {
  final AssistantPhase phase;
  final bool compact;

  const AssistantHero({super.key, required this.phase, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('assistant-hero'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AssistantTheme.border),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F2C21), Color(0xFF0A1C15), AssistantTheme.card],
        ),
        boxShadow: [
          BoxShadow(
            color: AssistantTheme.mint.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _FieldGridPainter()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, compact ? 12 : 18, 16, 16),
            child: compact
                ? Row(
                    children: [
                      AssistantOrb(phase: phase, size: 64),
                      const SizedBox(width: 12),
                      const Expanded(child: _Greeting(compact: true)),
                    ],
                  )
                : Column(
                    children: [
                      AssistantOrb(phase: phase),
                      const SizedBox(height: 8),
                      const _Greeting(compact: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final bool compact;
  const _Greeting({required this.compact});

  @override
  Widget build(BuildContext context) {
    final align = compact ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = compact ? TextAlign.start : TextAlign.center;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'স্বাগতম, কৃষক বন্ধু',
          textAlign: textAlign,
          style: TextStyle(
            color: AssistantTheme.text,
            fontSize: compact ? 16 : 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            'ফসল, আবহাওয়া বা বাজার নিয়ে জিজ্ঞেস করুন',
            textAlign: textAlign,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          alignment: compact ? WrapAlignment.start : WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            AssistantPill(
              label: '${DemoStory.fieldCropBn} · ${DemoStory.demoTagBn}',
              color: AssistantTheme.mint,
              icon: Icons.location_on_rounded,
            ),
            const AssistantPill(
              key: ValueKey('assistant-status-badge'),
              label: 'ডেমো মোড · লাইভ AI সংযুক্ত নয়',
              color: AssistantTheme.amber,
              icon: Icons.science_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

/// Faint plot-boundary grid, echoing satellite field maps.
class _FieldGridPainter extends CustomPainter {
  const _FieldGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AssistantTheme.mint.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - 18, size.height), p);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// Suggested questions
// ============================================================

class AssistantSuggestions extends StatelessWidget {
  final ValueChanged<String>? onPick;

  /// Wrap in the empty state, a single horizontal row once chatting.
  final bool scrollable;

  const AssistantSuggestions({
    super.key,
    required this.onPick,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (var i = 0; i < assistantSuggestedQuestions.length; i++)
        _chip(assistantSuggestedQuestions[i], i),
    ];
    if (!scrollable) {
      return Wrap(spacing: 8, runSpacing: 8, children: chips);
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(String q, int i) {
    return AssistantReveal(
      index: i,
      child: AssistantPressable(
        key: ValueKey('assistant-suggestion-$i'),
        onTap: onPick == null ? null : () => onPick!(q),
        // Bounded so long questions ellipsize on narrow screens and so the
        // Flexible below also works inside the unbounded horizontal list.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: AssistantTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AssistantTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: AssistantTheme.mint,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    q,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AssistantTheme.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

// ============================================================
// Quick actions
// ============================================================

class AssistantQuickActions extends StatelessWidget {
  final ValueChanged<AssistantDestination> onOpen;

  const AssistantQuickActions({super.key, required this.onOpen});

  static const _items = [
    (AssistantDestination.scan, 'গাছ স্ক্যান', 'Scan Plant'),
    (AssistantDestination.weather, 'আবহাওয়া', 'Weather'),
    (AssistantDestination.fields, 'আমার জমি', 'My Fields'),
    (AssistantDestination.market, 'বাজারদর', 'Market'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AssistantPressable(
              key: ValueKey('assistant-quick-${_items[i].$1.name}'),
              onTap: () => onOpen(_items[i].$1),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                decoration: BoxDecoration(
                  color: AssistantTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AssistantTheme.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _items[i].$1.icon,
                      color: AssistantTheme.mint,
                      size: 21,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _items[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AssistantTheme.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AssistantEnLabel(_items[i].$3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// Offline banner
// ============================================================

class AssistantOfflineBanner extends StatelessWidget {
  const AssistantOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('assistant-offline-banner'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AssistantTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AssistantTheme.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AssistantTheme.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'আপনি অফলাইনে আছেন',
                  style: TextStyle(
                    color: AssistantTheme.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ডেমো উত্তরগুলো ডিভাইসেই তৈরি হয়, তাই এখনো দেখা যাবে।',
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

// ============================================================
// Voice dock
// ============================================================

class AssistantVoiceDock extends StatefulWidget {
  final AssistantPhase phase;
  final String? errorBn;
  final ValueChanged<String> onSubmit;
  final VoidCallback onMic;

  const AssistantVoiceDock({
    super.key,
    required this.phase,
    required this.errorBn,
    required this.onSubmit,
    required this.onMic,
  });

  @override
  State<AssistantVoiceDock> createState() => _AssistantVoiceDockState();
}

class _AssistantVoiceDockState extends State<AssistantVoiceDock> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final busy =
        phase == AssistantPhase.processing || phase == AssistantPhase.listening;
    final status = phase == AssistantPhase.error && widget.errorBn != null
        ? widget.errorBn!
        : phase.statusBn;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
      decoration: BoxDecoration(
        color: AssistantTheme.bg.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AssistantTheme.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AssistantEqualizer(phase: phase),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AssistantTheme.reduceMotion(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: Text(
                    status,
                    key: ValueKey('assistant-status-$phase-$status'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: phase.color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: BoxDecoration(
                    color: AssistantTheme.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AssistantTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('assistant-input'),
                          controller: _controller,
                          enabled: !busy,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submit(),
                          cursorColor: AssistantTheme.mint,
                          style: const TextStyle(
                            color: AssistantTheme.text,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'প্রশ্ন লিখুন…',
                            hintStyle: TextStyle(
                              color: AssistantTheme.muted,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                      AssistantPressable(
                        key: const ValueKey('assistant-send'),
                        semanticLabel: 'পাঠান',
                        onTap: busy ? null : _submit,
                        child: const Icon(
                          Icons.send_rounded,
                          color: AssistantTheme.mint,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AssistantMicButton(
                phase: phase,
                onTap: phase == AssistantPhase.processing ? null : widget.onMic,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
