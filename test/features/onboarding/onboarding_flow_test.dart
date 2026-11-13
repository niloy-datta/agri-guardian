import 'package:agri_guardian/app/route_paths.dart';
import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:agri_guardian/features/onboarding/application/onboarding_providers.dart';
import 'package:agri_guardian/features/onboarding/data/device_location_resolver.dart';
import 'package:agri_guardian/features/onboarding/data/onboarding_store.dart';
import 'package:agri_guardian/features/onboarding/domain/onboarding_profile.dart';
import 'package:agri_guardian/features/onboarding/presentation/screens/analysis_screen.dart';
import 'package:agri_guardian/features/onboarding/presentation/screens/farm_info_screen.dart';
import 'package:agri_guardian/features/onboarding/presentation/screens/field_screen.dart';
import 'package:agri_guardian/features/onboarding/presentation/screens/goal_screen.dart';
import 'package:agri_guardian/features/onboarding/presentation/screens/language_screen.dart';
import 'package:agri_guardian/features/onboarding/presentation/screens/location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory store so the flow tests never touch platform preferences.
class _MemoryStore implements OnboardingStore {
  OnboardingProfile profile = const OnboardingProfile();
  bool complete = false;
  int writes = 0;

  @override
  Future<OnboardingProfile> read() async => profile;

  @override
  Future<void> write(OnboardingProfile p) async {
    profile = p;
    writes++;
  }

  @override
  Future<bool> isComplete() async => complete;

  @override
  Future<void> markComplete() async => complete = true;

  @override
  Future<void> clear() async {
    profile = const OnboardingProfile();
    complete = false;
  }
}

/// Mirrors `AgriGuardianApp`: the app locale follows the saved onboarding
/// language, so switching language rebuilds the remaining steps.
class _LocaleHost extends ConsumerWidget {
  const _LocaleHost({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language =
        ref.watch(onboardingControllerProvider).valueOrNull?.language ??
        AppLanguage.bangla;
    return MaterialApp.router(
      locale: Locale(language.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _StubLocationResolver implements DeviceLocationResolver {
  final DeviceLocationResult result;
  _StubLocationResolver(this.result);

  @override
  Future<DeviceLocationResult> resolve() async => result;
}

void main() {
  late _MemoryStore store;

  setUp(() => store = _MemoryStore());

  GoRouter buildRouter({String initial = RoutePaths.onboardingLocation}) {
    return GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: RoutePaths.onboardingLocation,
          builder: (_, _) => const OnboardingLocationScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboardingLanguage,
          builder: (_, _) => const OnboardingLanguageScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboardingFarm,
          builder: (_, _) => const OnboardingFarmInfoScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboardingField,
          builder: (_, _) => const OnboardingFieldScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboardingGoal,
          builder: (_, _) => const OnboardingGoalScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboardingAnalysis,
          builder: (_, _) =>
              const OnboardingAnalysisScreen(duration: Duration(seconds: 1)),
        ),
        GoRoute(path: RoutePaths.home, builder: (_, _) => const Text('HOME')),
      ],
    );
  }

  Future<GoRouter> pumpFlow(
    WidgetTester tester, {
    String initial = RoutePaths.onboardingLocation,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = buildRouter(initial: initial);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingStoreProvider.overrideWithValue(store),
          ...overrides,
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _LocaleHost(router: router),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('location step', () {
    testWidgets('manual entry enables continue and is saved', (tester) async {
      await pumpFlow(tester);

      // Default language is Bangla, so the heading is Bangla only.
      expect(find.text('আপনার খামার কোথায়?'), findsOneWidget);
      expect(find.text('খামারের অবস্থান'), findsOneWidget);
      expect(find.text('Where is your farm?'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('onboarding-choose-manually')),
      );
      await tester.pumpAndSettle();

      // Nothing entered yet, so continue action is disabled.
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('onboarding-continue')),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.byType(TextField),
        'কিশোরগঞ্জ সদর, কিশোরগঞ্জ',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
      await tester.pumpAndSettle();

      expect(store.profile.location?.label, 'কিশোরগঞ্জ সদর, কিশোরগঞ্জ');
      expect(store.profile.location?.mode, LocationMode.manual);
      expect(store.profile.location?.hasCoordinates, isFalse);
      expect(find.text('কোন ভাষায় চালাবেন?'), findsOneWidget);
    });

    testWidgets('a real fix is stored with its coordinates', (tester) async {
      await pumpFlow(
        tester,
        overrides: [
          deviceLocationResolverProvider.overrideWithValue(
            _StubLocationResolver(
              const DeviceLocationResult.success(24.4331, 90.7855),
            ),
          ),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding-use-my-location')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-location-fix')),
        findsOneWidget,
      );
      expect(find.textContaining('24.4331, 90.7855'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'কিশোরগঞ্জ');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
      await tester.pumpAndSettle();

      expect(store.profile.location?.mode, LocationMode.device);
      expect(store.profile.location?.latitude, 24.4331);
    });

    testWidgets('a denied fix falls back to typing, never a guessed place', (
      tester,
    ) async {
      await pumpFlow(
        tester,
        overrides: [
          deviceLocationResolverProvider.overrideWithValue(
            _StubLocationResolver(
              const DeviceLocationResult.failed(
                LocationFailure.permissionDenied,
              ),
            ),
          ),
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey('onboarding-use-my-location')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-location-failure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-location-fix')),
        findsNothing,
      );
      // No coordinates were invented to stand in for the failed fix.
      final primary = tester.widget<FilledButton>(
        find.byKey(const ValueKey('onboarding-continue')),
      );
      expect(primary.onPressed, isNull);
    });
  });

  testWidgets('language step stores the choice', (tester) async {
    await pumpFlow(tester, initial: RoutePaths.onboardingLanguage);

    await tester.tap(find.byKey(const ValueKey('onboarding-language-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('পরবর্তী ধাপ'));
    await tester.pumpAndSettle();

    expect(store.profile.language, AppLanguage.english);
    // The very next step renders in English immediately, with no Bangla.
    expect(find.text('About your farm'), findsOneWidget);
    expect(find.text('আপনার খামার সম্পর্কে'), findsNothing);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('পরবর্তী ধাপ'), findsNothing);
  });

  testWidgets('switching back to Bangla makes the next steps Bangla again', (
    tester,
  ) async {
    store.profile = const OnboardingProfile(language: AppLanguage.english);
    await pumpFlow(tester, initial: RoutePaths.onboardingLanguage);

    expect(find.text('Which language should we use?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-language-bn')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();

    expect(store.profile.language, AppLanguage.bangla);
    expect(find.text('আপনার খামার সম্পর্কে'), findsOneWidget);
    expect(find.text('About your farm'), findsNothing);
  });

  testWidgets('English goal and analysis steps have no Bangla text', (
    tester,
  ) async {
    store.profile = const OnboardingProfile(language: AppLanguage.english);
    await pumpFlow(tester, initial: RoutePaths.onboardingGoal);

    expect(find.text('What is your main goal?'), findsOneWidget);
    expect(find.text('Save water'), findsOneWidget);
    expect(find.text('Cut irrigation costs'), findsOneWidget);
    expect(find.text('আপনার মূল লক্ষ্য কী?'), findsNothing);
    expect(find.text('পানি সাশ্রয়'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('onboarding-goal-saveWater')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    // setGoal writes before navigating, so let the async write settle.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Preparing your farm'), findsOneWidget);
    expect(find.text('Matching your area'), findsOneWidget);
    expect(find.text('আপনার মাঠ প্রস্তুত করা হচ্ছে'), findsNothing);
    await tester.pumpAndSettle();
  });

  group('farm info step', () {
    testWidgets('requires name, a valid size and a crop', (tester) async {
      await pumpFlow(tester, initial: RoutePaths.onboardingFarm);

      FilledButton primary() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'পরবর্তী ধাপ'),
      );
      expect(primary().onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-farmer-name')),
        'নিলয়',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-farm-size')),
        'abc',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('একটি সঠিক সংখ্যা লিখুন (ইংরেজি অঙ্কে)।'),
        findsOneWidget,
      );
      expect(primary().onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('onboarding-farm-size')),
        '2.5',
      );
      await tester.pumpAndSettle();
      expect(primary().onPressed, isNull, reason: 'crop still missing');

      await tester.tap(find.text('বোরো ধান').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('পরবর্তী ধাপ'));
      await tester.pumpAndSettle();

      expect(store.profile.farmerName, 'নিলয়');
      expect(store.profile.farmSizeAcres, 2.5);
      expect(store.profile.currentCrop, 'বোরো ধান');
      expect(find.text('আপনার জমি চিহ্নিত করুন'), findsOneWidget);
    });
  });

  group('field step', () {
    testWidgets('stores a boundary drawn with the real picker contract', (
      tester,
    ) async {
      await pumpFlow(
        tester,
        initial: RoutePaths.onboardingField,
        overrides: [
          onboardingBoundaryPickerProvider.overrideWithValue(
            (_) async => {
              'type': 'Polygon',
              'coordinates': [
                [
                  [90.40, 24.40],
                  [90.41, 24.40],
                  [90.41, 24.41],
                  [90.40, 24.40],
                ],
              ],
            },
          ),
        ],
      );

      expect(find.text('সীমানা আঁকা হয়নি'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-draw-field')));
      await tester.pumpAndSettle();

      expect(find.text('সীমানা আঁকা হয়েছে'), findsOneWidget);
      // The closing point that repeats the first is not counted.
      expect(find.text('3 টি বিন্দু'), findsOneWidget);

      final loam = find.byKey(const ValueKey('onboarding-soil-loam'));
      await tester.scrollUntilVisible(loam, 100);
      await tester.pumpAndSettle();
      await tester.tap(loam);
      await tester.pumpAndSettle();
      await tester.tap(find.text('পরবর্তী ধাপ'));
      await tester.pumpAndSettle();

      expect(store.profile.fieldBoundary?.vertexCount, 3);
      expect(store.profile.fieldBoundary?.geoJson['type'], 'Polygon');
      expect(store.profile.soilType, SoilType.loam);
      expect(find.text('আপনার মূল লক্ষ্য কী?'), findsOneWidget);
    });

    testWidgets('the field step can be skipped', (tester) async {
      await pumpFlow(tester, initial: RoutePaths.onboardingField);

      await tester.tap(find.text('এখন বাদ দিন'));
      await tester.pumpAndSettle();

      expect(store.profile.fieldBoundary, isNull);
      expect(find.text('আপনার মূল লক্ষ্য কী?'), findsOneWidget);
    });
  });

  testWidgets('goal step stores the goal and reaches the transition', (
    tester,
  ) async {
    await pumpFlow(tester, initial: RoutePaths.onboardingGoal);

    await tester.tap(find.byKey(const ValueKey('onboarding-goal-saveWater')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('শেষ করুন'));
    // setGoal writes before navigating, so let the async write settle.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(store.profile.goal, FarmGoal.saveWater);
    expect(find.text('আপনার মাঠ প্রস্তুত করা হচ্ছে'), findsOneWidget);
  });

  group('analysis transition', () {
    testWidgets('says it computes nothing, then completes setup', (
      tester,
    ) async {
      await pumpFlow(tester, initial: RoutePaths.onboardingAnalysis);

      expect(
        find.textContaining('কোনো লাইভ'),
        findsOneWidget,
        reason: 'must not imply a live satellite or weather computation',
      );
      expect(find.textContaining('NASA'), findsNothing);
      expect(store.complete, isFalse);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(store.complete, isTrue);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  testWidgets('back steps return to the previous screen', (tester) async {
    await pumpFlow(tester, initial: RoutePaths.onboardingFarm);

    await tester.tap(find.bySemanticsLabel('আগের ধাপ'));
    await tester.pumpAndSettle();

    expect(find.text('কোন ভাষায় চালাবেন?'), findsOneWidget);
  });

  group('SharedPrefsOnboardingStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips a profile and the completion flag', () async {
      final store = SharedPrefsOnboardingStore();

      expect(await store.isComplete(), isFalse);
      expect((await store.read()).isComplete, isFalse);

      await store.write(
        const OnboardingProfile(
          language: AppLanguage.bangla,
          location: FarmLocation(
            mode: LocationMode.device,
            label: 'কিশোরগঞ্জ',
            latitude: 24.4331,
            longitude: 90.7855,
          ),
          farmerName: 'নিলয়',
          farmSizeAcres: 2.5,
          currentCrop: 'বোরো ধান',
          fieldBoundary: FieldBoundaryDraft(
            geoJson: {'type': 'Polygon'},
            vertexCount: 4,
          ),
          previousCrop: 'গম',
          soilType: SoilType.loam,
          goal: FarmGoal.increaseYield,
        ),
      );
      await store.markComplete();

      final restored = await SharedPrefsOnboardingStore().read();
      expect(restored.language, AppLanguage.bangla);
      expect(restored.location?.mode, LocationMode.device);
      expect(restored.location?.latitude, 24.4331);
      expect(restored.farmerName, 'নিলয়');
      expect(restored.farmSizeAcres, 2.5);
      expect(restored.currentCrop, 'বোরো ধান');
      expect(restored.fieldBoundary?.vertexCount, 4);
      expect(restored.previousCrop, 'গম');
      expect(restored.soilType, SoilType.loam);
      expect(restored.goal, FarmGoal.increaseYield);
      expect(restored.isComplete, isTrue);
      expect(await SharedPrefsOnboardingStore().isComplete(), isTrue);
    });

    test('clear wipes both the answers and the flag', () async {
      final store = SharedPrefsOnboardingStore();
      await store.write(
        const OnboardingProfile(farmerName: 'নিলয়', farmSizeAcres: 2),
      );
      await store.markComplete();

      await store.clear();

      final after = await store.read();
      expect(after.farmerName, isNull);
      expect(after.farmSizeAcres, isNull);
      expect(await store.isComplete(), isFalse);
    });
  });
}
