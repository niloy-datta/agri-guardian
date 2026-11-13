import 'package:flutter/material.dart';

import '../../domain/assistant_models.dart';
import 'assistant_orb.dart';
import 'assistant_theme.dart';

class FarmerBubble extends StatelessWidget {
  final FarmerMessage message;

  const FarmerBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF16513A), Color(0xFF0F3A2A)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
            border: Border.all(
              color: AssistantTheme.mint.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.text,
                style: const TextStyle(
                  color: AssistantTheme.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.viaVoice) ...[
                    const Icon(
                      Icons.mic_rounded,
                      size: 11,
                      color: AssistantTheme.muted,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    bnClock(message.sentAt),
                    style: const TextStyle(
                      color: AssistantTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Structured answer: direct answer, reason, evidence chips, origin
/// state, next step and in-app actions.
class AssistantAnswerCard extends StatelessWidget {
  final AssistantAnswer answer;
  final ValueChanged<AssistantDestination> onAction;

  const AssistantAnswerCard({
    super.key,
    required this.answer,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final originColor = answer.origin.color;
    final reason = answer.reasonBn;
    final nextStep = answer.nextStepBn;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AssistantTheme.cardRaised, AssistantTheme.card],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(AssistantTheme.radius),
          bottomLeft: Radius.circular(AssistantTheme.radius),
          bottomRight: Radius.circular(AssistantTheme.radius),
        ),
        border: Border.all(color: AssistantTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AssistantTheme.mint,
                      AssistantTheme.green.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'মুক্তি সহকারী',
                style: TextStyle(
                  color: AssistantTheme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AssistantPill(
                    key: const ValueKey('assistant-answer-origin'),
                    label: answer.origin.labelBn,
                    color: originColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answer.directAnswerBn,
            style: const TextStyle(
              color: AssistantTheme.text,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          if (reason != null) ...[
            const SizedBox(height: 10),
            _Labeled(labelBn: 'কারণ', child: _body(reason)),
          ],
          if (answer.evidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Labeled(
              labelBn: 'প্রমাণ ও উৎস',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in answer.evidence)
                    AssistantPill(
                      label: e.labelBn,
                      color: e.kind.color,
                      icon: e.kind.icon,
                    ),
                ],
              ),
            ),
          ],
          if (nextStep != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AssistantTheme.mint.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AssistantTheme.mint.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_circle_right_rounded,
                    size: 16,
                    color: AssistantTheme.mint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'পরবর্তী পদক্ষেপ',
                          style: TextStyle(
                            color: AssistantTheme.mint,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _body(nextStep),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (answer.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final action in answer.actions)
                  AssistantPressable(
                    onTap: () => onAction(action.destination),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AssistantTheme.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AssistantTheme.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            action.destination.icon,
                            size: 15,
                            color: AssistantTheme.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            action.labelBn,
                            style: const TextStyle(
                              color: AssistantTheme.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _body(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.78),
      fontSize: 12.5,
      height: 1.45,
    ),
  );
}

class _Labeled extends StatelessWidget {
  final String labelBn;
  final Widget child;

  const _Labeled({required this.labelBn, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelBn,
          style: const TextStyle(
            color: AssistantTheme.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class AssistantFailureCard extends StatelessWidget {
  final VoidCallback onRetry;

  const AssistantFailureCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AssistantTheme.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AssistantTheme.radius),
        border: Border.all(color: AssistantTheme.red.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AssistantTheme.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'উত্তর আনা যায়নি',
                  style: TextStyle(
                    color: AssistantTheme.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                AssistantEnLabel('Could not get an answer'),
              ],
            ),
          ),
          AssistantPressable(
            key: const ValueKey('assistant-retry'),
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AssistantTheme.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 15, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'আবার চেষ্টা',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
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

/// Shown while the answer engine is working.
class AssistantThinkingCard extends StatelessWidget {
  const AssistantThinkingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('assistant-thinking'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AssistantTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AssistantTheme.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssistantEqualizer(phase: AssistantPhase.processing),
            SizedBox(width: 10),
            Text(
              'ভাবছি…',
              style: TextStyle(
                color: AssistantTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
