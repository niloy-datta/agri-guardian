/// go_router path constants. Replaces the old `RouteNames` string table
/// (`lib/core/routing/route_names.dart`), kept only until every legacy
/// `Navigator.push`/`MaterialPageRoute` call site is migrated.
class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';
  static const String auth = '/auth';

  // --- First-run setup, between the splash and the dashboard. Each step
  // is its own top-level route (no bottom nav) so the flow stays focused,
  // and `OnboardingStore` decides whether the splash enters it at all.
  static const String onboardingLocation = '/onboarding/location';
  static const String onboardingLanguage = '/onboarding/language';
  static const String onboardingFarm = '/onboarding/farm';
  static const String onboardingField = '/onboarding/field';
  static const String onboardingGoal = '/onboarding/goal';
  static const String onboardingAnalysis = '/onboarding/analysis';

  static const String home = '/';
  static const String fields = '/fields';
  static const String fieldDetails = '/field-details/:id';
  static const String fieldInsights = '/field-insights';
  static const String profile = '/profile';
  static const String scan = '/scan';
  static const String scanResult = '/scan-result';
  static const String treatmentPlan = '/treatment-plan';
  // Nested under the Insights tab's shell branch so the persistent bottom
  // nav bar stays visible on this screen.
  static const String satelliteAnalysis = '/field-insights/satellite-analysis';
  // Nested under the Home tab's shell branch, same reason.
  static const String weather = '/weather';
  static const String irrigation = '/irrigation';
  static const String marketPrice = '/market-price';
  static const String aiAssistant = '/ai-assistant';

  // --- Marketplace (Phase 12B) ---
  static const String marketplace = '/marketplace';
  static const String marketplaceListingDetail = '/marketplace/listing/:id';
  static const String marketplaceCreateListing = '/marketplace/create';
  static const String marketplaceListingBids = '/marketplace/listing/:id/bids';
  static const String marketplaceOrderDetail = '/marketplace/order/:id';

  static String fieldDetailsPath(String fieldId) => '/field-details/$fieldId';

  static String marketplaceListingDetailPath(String listingId) =>
      '/marketplace/listing/$listingId';

  static String marketplaceListingBidsPath(String listingId) =>
      '/marketplace/listing/$listingId/bids';

  static String marketplaceOrderDetailPath(String orderId) =>
      '/marketplace/order/$orderId';
}
