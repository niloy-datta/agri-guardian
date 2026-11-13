import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/onboarding_providers.dart';
import '../../domain/onboarding_profile.dart';
import '../widgets/onboarding_scaffold.dart';

/// Step 2 - interface language. Stored as a preference; the app's own
/// screens are Bangla-first either way in this phase.
class OnboardingLanguageScreen extends ConsumerStatefulWidget {
  const OnboardingLanguageScreen({super.key});

  @override
  ConsumerState<OnboardingLanguageScreen> createState() =>
      _OnboardingLanguageScreenState();
}

class _OnboardingLanguageScreenState
    extends ConsumerState<OnboardingLanguageScreen> {
  AppLanguage? _language;

  @override
  void initState() {
    super.initState();
    _language =
        ref.read(onboardingControllerProvider).valueOrNull?.language ??
        AppLanguage.bangla;
  }

  Future<void> _continue() async {
    await ref
        .read(onboardingControllerProvider.notifier)
        .setLanguage(_language!);
    if (mounted) context.go(RoutePaths.onboardingFarm);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingScaffold(
      step: 2,
      title: l10n.chooseAppLanguage,
      subtitle: l10n.languageChangeLater,
      onBack: () => context.go(RoutePaths.onboardingLocation),
      primaryLabel: l10n.nextStep,
      onPrimary: _language == null ? null : _continue,
      children: [
        OnboardingChoiceTile(
          key: const ValueKey('onboarding-language-bn'),
          icon: Icons.translate_rounded,
          title: 'বাংলা',
          subtitle: l10n.banglaMainLanguage,
          selected: _language == AppLanguage.bangla,
          onTap: () => setState(() => _language = AppLanguage.bangla),
        ),
        const SizedBox(height: 10),
        OnboardingChoiceTile(
          key: const ValueKey('onboarding-language-en'),
          icon: Icons.language_rounded,
          title: 'English',
          subtitle: l10n.englishInterface,
          selected: _language == AppLanguage.english,
          onTap: () => setState(() => _language = AppLanguage.english),
          accent: OnboardingTheme.blue,
        ),
      ],
    );
  }
}
