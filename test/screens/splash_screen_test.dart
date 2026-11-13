import 'package:agri_guardian/app/route_paths.dart';
import 'package:agri_guardian/features/onboarding/application/onboarding_providers.dart';
import 'package:agri_guardian/features/onboarding/data/onboarding_store.dart';
import 'package:agri_guardian/features/onboarding/domain/onboarding_profile.dart';
import 'package:agri_guardian/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeOnboardingStore implements OnboardingStore {
  final bool complete;
  _FakeOnboardingStore({this.complete = false});

  @override
  Future<OnboardingProfile> read() async => const OnboardingProfile();

  @override
  Future<void> write(OnboardingProfile profile) async {}

  @override
  Future<bool> isComplete() async => complete;

  @override
  Future<void> markComplete() async {}

  @override
  Future<void> clear() async {}
}

void main() {
  Widget buildTestApp({
    required bool onboardingComplete,
    required List<String> navigatedRoutes,
  }) {
    final router = GoRouter(
      initialLocation: RoutePaths.splash,
      routes: [
        GoRoute(
          path: RoutePaths.splash,
          builder: (_, _) => const SplashScreen(),
        ),
        GoRoute(
          path: RoutePaths.onboardingLocation,
          builder: (_, _) {
            navigatedRoutes.add(RoutePaths.onboardingLocation);
            return const Scaffold(body: Text('ONBOARDING_LOCATION'));
          },
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) {
            navigatedRoutes.add(RoutePaths.home);
            return const Scaffold(body: Text('HOME_SCREEN'));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        onboardingStoreProvider.overrideWithValue(
          _FakeOnboardingStore(complete: onboardingComplete),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('renders clean premium splash with brand, headline, subtitle, and single CTA',
      (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(
      buildTestApp(onboardingComplete: false, navigatedRoutes: routes),
    );
    await tester.pump();

    // Brand chip
    expect(find.text('AgriLume'), findsOneWidget);
    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);

    // Headline & small sub-caption
    expect(find.text('See Your Farm.\nKnow What’s Next.'), findsOneWidget);
    expect(
      find.text('Earth intelligence for smarter farming.'),
      findsOneWidget,
    );

    // Single CTA button
    expect(find.widgetWithText(FilledButton, 'Get Started'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    // Verify absence of clutter: No Skip button, no old carousel copy
    expect(find.text('Skip'), findsNothing);
    expect(find.text('01  •  EARTH SIGNAL'), findsNothing);
    expect(find.text('02  •  AGRILUME'), findsNothing);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('tapping Get Started navigates to onboarding when not completed',
      (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(
      buildTestApp(onboardingComplete: false, navigatedRoutes: routes),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
    await tester.pumpAndSettle();

    expect(routes, contains(RoutePaths.onboardingLocation));
    expect(find.text('ONBOARDING_LOCATION'), findsOneWidget);
  });

  testWidgets('tapping Get Started navigates to home when onboarding is complete',
      (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(
      buildTestApp(onboardingComplete: true, navigatedRoutes: routes),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
    await tester.pumpAndSettle();

    expect(routes, contains(RoutePaths.home));
    expect(find.text('HOME_SCREEN'), findsOneWidget);
  });
}
