import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../application/assistant_controller.dart';
import '../../domain/assistant_models.dart';
import '../widgets/assistant_messages.dart';
import '../widgets/assistant_panels.dart';
import '../widgets/assistant_theme.dart';

/// AI কৃষি সহকারী - nested under the Home shell branch, so `MainShell`'s
/// bottom nav stays visible below it.
///
/// Reads only [AssistantState]; the answer engine and voice input behind
/// it are swappable providers (demo engine, no speech yet - see
/// `assistant_controller.dart`).
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (AssistantTheme.reduceMotion(context)) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _open(AssistantDestination destination) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    switch (destination) {
      case AssistantDestination.scan:
        router.push(RoutePaths.scan);
      case AssistantDestination.weather:
        router.push(RoutePaths.weather);
      case AssistantDestination.fields:
        router.go(RoutePaths.fields);
      case AssistantDestination.market:
        router.push(RoutePaths.marketPrice);
    }
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      assistantControllerProvider.select((s) => s.messages.length),
      (_, _) => _scrollToEnd(),
    );

    final state = ref.watch(assistantControllerProvider);
    final controller = ref.read(assistantControllerProvider.notifier);
    final isOffline =
        ref.watch(assistantIsOfflineProvider).valueOrNull ?? false;
    final hasChat = state.messages.isNotEmpty;
    final canAsk = state.phase != AssistantPhase.processing &&
        state.phase != AssistantPhase.listening;

    return Scaffold(
      backgroundColor: AssistantTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: _Header(
                    onBack: _back,
                    onClear: hasChat && canAsk
                        ? controller.clearConversation
                        : null,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      AssistantReveal(
                        child: AssistantHero(
                          phase: state.phase,
                          compact: hasChat,
                        ),
                      ),
                      if (isOffline) ...[
                        const SizedBox(height: 10),
                        const AssistantOfflineBanner(),
                      ],
                      if (!hasChat) ...[
                        const SizedBox(height: 20),
                        const _SectionLabel(
                          titleBn: 'প্রশ্ন করে দেখুন',
                          titleEn: 'Try asking',
                        ),
                        const SizedBox(height: 10),
                        AssistantSuggestions(
                          onPick: canAsk ? controller.ask : null,
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        for (final m in state.messages) ...[
                          AssistantReveal(
                            key: ValueKey('assistant-message-${m.id}'),
                            child: switch (m) {
                              FarmerMessage() => FarmerBubble(message: m),
                              AssistantReply() => AssistantAnswerCard(
                                answer: m.answer,
                                onAction: _open,
                              ),
                              AssistantFailure() => AssistantFailureCard(
                                onRetry: () => controller.retry(m),
                              ),
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (state.phase == AssistantPhase.processing) ...[
                          const AssistantThinkingCard(),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 4),
                        AssistantSuggestions(
                          scrollable: true,
                          onPick: canAsk ? controller.ask : null,
                        ),
                      ],
                      const SizedBox(height: 20),
                      const _SectionLabel(
                        titleBn: 'দ্রুত যান',
                        titleEn: 'Quick actions',
                      ),
                      const SizedBox(height: 10),
                      AssistantQuickActions(onOpen: _open),
                    ],
                  ),
                ),
                AssistantVoiceDock(
                  phase: state.phase,
                  errorBn: state.errorBn,
                  onSubmit: controller.ask,
                  onMic: controller.startVoice,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onClear;

  const _Header({required this.onBack, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AssistantPressable(
          onTap: onBack,
          semanticLabel: 'ফিরে যান',
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AssistantTheme.card,
              shape: BoxShape.circle,
              border: Border.all(color: AssistantTheme.line),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AssistantTheme.text,
              size: 19,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI কৃষি সহকারী',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AssistantTheme.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              AssistantEnLabel('Voice-first farm assistant'),
            ],
          ),
        ),
        if (onClear != null)
          AssistantPressable(
            key: const ValueKey('assistant-clear'),
            onTap: onClear,
            semanticLabel: 'কথোপকথন মুছুন',
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AssistantTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: AssistantTheme.line),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: AssistantTheme.muted,
                size: 19,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String titleBn;
  final String titleEn;

  const _SectionLabel({required this.titleBn, required this.titleEn});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          titleBn,
          style: const TextStyle(
            color: AssistantTheme.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: AssistantEnLabel(titleEn)),
      ],
    );
  }
}
