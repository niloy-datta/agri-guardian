import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/onboarding_providers.dart';
import '../../domain/onboarding_profile.dart';
import '../widgets/onboarding_scaffold.dart';

/// Step 5 - what the farmer most wants out of the app.
class OnboardingGoalScreen extends ConsumerStatefulWidget {
  const OnboardingGoalScreen({super.key});

  @override
  ConsumerState<OnboardingGoalScreen> createState() =>
      _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends ConsumerState<OnboardingGoalScreen> {
  FarmGoal? _goal;

  static const _options = [
    (FarmGoal.saveWater, Icons.water_drop_outlined),
    (FarmGoal.increaseYield, Icons.trending_up_rounded),
    (FarmGoal.improveSoil, Icons.grass_rounded),
    (FarmGoal.reduceClimateRisk, Icons.thunderstorm_outlined),
    (FarmGoal.findNextCrop, Icons.explore_outlined),
  ];

  static (String, String) _goalText(AppLocalizations l10n, FarmGoal goal) =>
      switch (goal) {
        FarmGoal.saveWater => (l10n.goalSaveWater, l10n.goalSaveWaterHint),
        FarmGoal.increaseYield => (
          l10n.goalIncreaseYield,
          l10n.goalIncreaseYieldHint,
        ),
        FarmGoal.improveSoil => (
          l10n.goalImproveSoil,
          l10n.goalImproveSoilHint,
        ),
        FarmGoal.reduceClimateRisk => (
          l10n.goalClimateRisk,
          l10n.goalClimateRiskHint,
        ),
        FarmGoal.findNextCrop => (l10n.goalNextCrop, l10n.goalNextCropHint),
      };

  @override
  void initState() {
    super.initState();
    _goal = ref.read(onboardingControllerProvider).valueOrNull?.goal;
  }

  Future<void> _continue() async {
    await ref.read(onboardingControllerProvider.notifier).setGoal(_goal!);
    if (mounted) context.go(RoutePaths.onboardingAnalysis);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingScaffold(
      step: 5,
      title: l10n.mainGoalQuestion,
      subtitle: l10n.goalSubtitle,
      onBack: () => context.go(RoutePaths.onboardingField),
      primaryLabel: l10n.finishSetup,
      onPrimary: _goal == null ? null : _continue,
      children: [
        for (final (goal, icon) in _options) ...[
          OnboardingChoiceTile(
            key: ValueKey('onboarding-goal-${goal.name}'),
            icon: icon,
            title: _goalText(l10n, goal).$1,
            subtitle: _goalText(l10n, goal).$2,
            selected: _goal == goal,
            onTap: () => setState(() => _goal = goal),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
