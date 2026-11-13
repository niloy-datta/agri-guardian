import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/onboarding_store.dart';
import '../domain/onboarding_profile.dart';

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  return SharedPrefsOnboardingStore();
});

/// Whether setup has been finished before, so the splash knows whether to
/// hand off to the setup flow or straight to the dashboard.
final onboardingCompleteProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingStoreProvider).isComplete();
});

/// The in-progress setup answers. Each step writes as the farmer moves
/// forward, so backing out and returning keeps what they already gave.
class OnboardingController extends AsyncNotifier<OnboardingProfile> {
  @override
  Future<OnboardingProfile> build() {
    return ref.watch(onboardingStoreProvider).read();
  }

  Future<void> _update(
    OnboardingProfile Function(OnboardingProfile current) change,
  ) async {
    final current = state.valueOrNull ?? const OnboardingProfile();
    final next = change(current);
    state = AsyncData(next);
    await ref.read(onboardingStoreProvider).write(next);
  }

  Future<void> setLanguage(AppLanguage language) =>
      _update((c) => c.copyWith(language: language));

  Future<void> setLocation(FarmLocation location) =>
      _update((c) => c.copyWith(location: location));

  Future<void> setFarmInfo({
    required String farmerName,
    required double farmSizeAcres,
    required String currentCrop,
  }) {
    return _update(
      (c) => c.copyWith(
        farmerName: farmerName,
        farmSizeAcres: farmSizeAcres,
        currentCrop: currentCrop,
      ),
    );
  }

  Future<void> setFieldDetails({
    FieldBoundaryDraft? boundary,
    String? previousCrop,
    SoilType? soilType,
  }) {
    return _update(
      (c) => c.copyWith(
        fieldBoundary: boundary,
        previousCrop: previousCrop,
        soilType: soilType,
      ),
    );
  }

  Future<void> setGoal(FarmGoal goal) => _update((c) => c.copyWith(goal: goal));

  /// Called once the farmer reaches the end of setup.
  Future<void> finish() async {
    await ref.read(onboardingStoreProvider).markComplete();
    ref.invalidate(onboardingCompleteProvider);
  }

  /// Wipes stored setup answers - used by the Profile "redo setup" action
  /// and by tests.
  Future<void> reset() async {
    await ref.read(onboardingStoreProvider).clear();
    state = const AsyncData(OnboardingProfile());
    ref.invalidate(onboardingCompleteProvider);
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingProfile>(
      OnboardingController.new,
    );
