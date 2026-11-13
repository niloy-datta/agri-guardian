import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../screens/email_auth_screen.dart';

import '../screens/field_insights.dart';
import '../screens/home_dashboard_screen.dart';
import '../screens/market_intelligence.dart';
import '../screens/my_fields.dart';
import '../screens/profile.dart';
import '../screens/satellite_map.dart';
import '../screens/splash_screen.dart';
import '../screens/treatment_plan.dart';
import '../features/fields/presentation/screens/field_details_screen.dart';
import '../features/plant_scan/presentation/screens/scan_screen.dart';
import '../features/plant_scan/presentation/screens/scan_result_screen.dart';
import '../features/weather/presentation/screens/weather_screen.dart';
import '../features/irrigation/presentation/screens/irrigation_screen.dart';
import '../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../features/marketplace/presentation/screens/create_listing_screen.dart';
import '../features/onboarding/presentation/screens/analysis_screen.dart';
import '../features/onboarding/presentation/screens/farm_info_screen.dart';
import '../features/onboarding/presentation/screens/field_screen.dart';
import '../features/onboarding/presentation/screens/goal_screen.dart';
import '../features/onboarding/presentation/screens/language_screen.dart';
import '../features/onboarding/presentation/screens/location_screen.dart';
import 'main_shell.dart';
import 'route_paths.dart';

/// Single go_router navigation source of truth.
///
/// The 4 main tabs (Home, My Fields, Insights, Profile) are a
/// `StatefulShellRoute.indexedStack` wrapped by `MainShell`
/// (`main_shell.dart`), which supplies the persistent bottom nav bar.
/// Any screen nested as a *child* of one of these branches - Weather/
/// Market Price/AI Assistant under Home, the satellite/field-health
/// screen under Insights - keeps that same bottom nav bar visible, since
/// it stays inside the shell's own nested navigator. Screens that
/// deliberately have no bottom nav (a focused task, not a "section" of
/// the app) stay as ordinary top-level routes outside the shell: Splash,
/// the Scan -> diagnosis -> treatment-plan flow, a specific field's
/// detail page, and the marketplace create-listing form.
/// Root navigator. Exposed so app-wide overlays (the voice-guide menu) can
/// open sheets and dialogs above whichever route is showing.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class _AuthRefresh extends ChangeNotifier {
  StreamSubscription<User?>? _subscription;

  void start() {
    if (_subscription != null) return;
    if (Firebase.apps.isNotEmpty) {
      _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final _authRefresh = _AuthRefresh();

void startAuthRouterRefresh() => _authRefresh.start();

final GoRouter appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: RoutePaths.splash,
  refreshListenable: _authRefresh,
  redirect: (context, state) {
    // If Firebase is not configured or not initialized, do not force the user
    // into the auth screen. The app operates in demo/offline mode.
    if (!DefaultFirebaseOptions.isConfigured || Firebase.apps.isEmpty) {
      return null;
    }
    final signedIn = FirebaseAuth.instance.currentUser != null;
    if (!signedIn && state.matchedLocation != RoutePaths.auth) {
      return RoutePaths.auth;
    }
    if (signedIn && state.matchedLocation == RoutePaths.auth) {
      return RoutePaths.splash;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: RoutePaths.auth,
      builder: (context, state) => const EmailAuthScreen(),
    ),
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // First-run setup: splash -> location -> language -> farm -> field ->
    // goal -> analysis -> Home. Top-level (outside the shell) so these
    // focused steps carry no bottom nav, and skipped entirely on later
    // launches - see `OnboardingStore.isComplete`.
    GoRoute(
      path: RoutePaths.onboardingLocation,
      builder: (context, state) => const OnboardingLocationScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingLanguage,
      builder: (context, state) => const OnboardingLanguageScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingFarm,
      builder: (context, state) => const OnboardingFarmInfoScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingField,
      builder: (context, state) => const OnboardingFieldScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingGoal,
      builder: (context, state) => const OnboardingGoalScreen(),
    ),
    GoRoute(
      path: RoutePaths.onboardingAnalysis,
      builder: (context, state) => const OnboardingAnalysisScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.home,
              builder: (context, state) => const HomeDashboardScreen(),
              routes: [
                GoRoute(
                  path: 'weather',
                  builder: (context, state) => const WeatherScreen(),
                ),
                GoRoute(
                  path: 'market-price',
                  builder: (context, state) => const MarketIntelligenceScreen(),
                ),
                GoRoute(
                  path: 'ai-assistant',
                  builder: (context, state) => const AiAssistantScreen(),
                ),
              ],
            ),
          ],
        ),

        // Branch 1: My Fields
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.fields,
              builder: (context, state) => const MyFieldsScreen(),
            ),
          ],
        ),

        // Branch 2: Insights
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.fieldInsights,
              builder: (context, state) => const FieldInsightsScreen(),
              routes: [
                GoRoute(
                  path: 'satellite-analysis',
                  builder: (context, state) => const SatelliteMapScreen(),
                ),
              ],
            ),
          ],
        ),

        // Branch 3: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutePaths.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // ---- Outside the shell: focused, chrome-free flows ----
    GoRoute(
      path: RoutePaths.fieldDetails,
      builder: (context, state) =>
          FieldDetailsScreen(fieldId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: RoutePaths.scan,
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: RoutePaths.scanResult,
      builder: (context, state) => const ScanResultScreen(),
    ),
    GoRoute(
      path: RoutePaths.treatmentPlan,
      builder: (context, state) => const TreatmentPlanScreen(),
    ),
    GoRoute(
      path: RoutePaths.irrigation,
      builder: (context, state) => const IrrigationScreen(),
    ),
    // Only the create-listing form exists so far (Phase 12B.0 audit) - the
    // browse/listing-detail/seller-bid-inbox/order-detail screens are not
    // built yet, so only this one marketplace route is registered.
    GoRoute(
      path: RoutePaths.marketplaceCreateListing,
      builder: (context, state) => const CreateListingScreen(),
    ),
  ],
);
