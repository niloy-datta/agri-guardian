import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/route_paths.dart';
import '../../../app/router.dart';
import '../../../core/localization/app_localizations.dart';
import '../application/voice_guide_controller.dart';

/// Floating Bangla voice-guide button drawn over every screen.
///
/// Mounted from `MaterialApp.builder`, so it stays on top of the router and
/// shows on each page. Tap it to open the menu (read this page / tour the
/// app). While audio is playing, the same button turns into a stop button.
class VoiceGuideOverlay extends ConsumerWidget {
  const VoiceGuideOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(voiceGuideControllerProvider);

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              appRouter.routeInformationProvider,
              controller.isSpeaking,
            ]),
            builder: (context, _) {
              final path = controller.currentPath;
              if (path == RoutePaths.splash) return const SizedBox.shrink();

              // Sit above the bottom nav bar on the four main tabs.
              final inShell = controller.currentGuide?.inShell ?? false;
              final bottom =
                  MediaQuery.paddingOf(context).bottom + (inShell ? 96 : 16);

              return Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 16, bottom: bottom),
                  child: _VoiceGuideButton(
                    speaking: controller.isSpeaking.value,
                    onTap: () => _onTap(controller),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _onTap(VoiceGuideController controller) {
    if (controller.isSpeaking.value) {
      controller.stop();
      return;
    }
    _showMenu(controller);
  }

  /// Runs a narration. If the device has no voice for the selected language,
  /// nothing is spoken and the user is told in that language instead.
  Future<void> _run(
    BuildContext context,
    Future<VoiceRunResult> Function() action,
  ) async {
    final result = await action();
    if (result == VoiceRunResult.voiceUnavailable && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).voiceNotInstalled)),
      );
    }
  }

  void _showMenu(VoiceGuideController controller) {
    final navContext = appNavigatorKey.currentContext;
    if (navContext == null) return;

    final l10n = AppLocalizations.of(navContext);
    final title = controller.currentGuide?.titleFor(isBangla: l10n.isBangla);

    showModalBottomSheet<void>(
      context: navContext,
      backgroundColor: const Color(0xFF0B1713),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.voiceGuideTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF5FFF8),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title == null
                      ? l10n.voiceGuideNoScreen
                      : l10n.voiceGuideCurrentScreen(title),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF829B90),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                _MenuTile(
                  icon: Icons.menu_book_rounded,
                  label: l10n.voiceGuideReadPage,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _run(
                      navContext,
                      () =>
                          controller.readCurrentScreen(isBangla: l10n.isBangla),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _MenuTile(
                  icon: Icons.route_rounded,
                  label: l10n.voiceGuideTour,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _run(
                      navContext,
                      () => controller.startTour(isBangla: l10n.isBangla),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VoiceGuideButton extends StatelessWidget {
  const _VoiceGuideButton({required this.speaking, required this.onTap});

  final bool speaking;
  final VoidCallback onTap;

  static const _green = Color(0xFF22E57F);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: speaking
            ? AppLocalizations.of(context).voiceGuideStop
            : AppLocalizations.of(context).voiceGuideTitle,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: speaking ? const Color(0xFFFFB020) : _green,
            boxShadow: [
              BoxShadow(
                color: (speaking ? const Color(0xFFFFB020) : _green).withValues(
                  alpha: 0.45,
                ),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            speaking ? Icons.stop_rounded : Icons.record_voice_over_rounded,
            color: const Color(0xFF050C09),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2118),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF163226)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF22E57F), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF5FFF8),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
