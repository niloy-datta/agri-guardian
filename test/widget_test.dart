import 'dart:convert';
import 'dart:typed_data';

import 'package:agri_guardian/app/app.dart';
import 'package:agri_guardian/core/network/api_client.dart';
import 'package:agri_guardian/features/fields/application/fields_providers.dart';
import 'package:agri_guardian/features/onboarding/application/onboarding_providers.dart';
import 'package:agri_guardian/features/onboarding/data/onboarding_store.dart';
import 'package:agri_guardian/features/onboarding/domain/onboarding_profile.dart';
import 'package:agri_guardian/screens/home_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = jsonEncode({
      'items': [],
      'next_cursor': null,
      'has_more': false,
    });
    return ResponseBody.fromString(
      payload,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Setup already finished, so the splash hands off to Home rather than
/// into the first-run flow. The onboarding path has its own tests.
class _CompletedOnboardingStore implements OnboardingStore {
  @override
  Future<OnboardingProfile> read() async => const OnboardingProfile();

  @override
  Future<void> write(OnboardingProfile profile) async {}

  @override
  Future<bool> isComplete() async => true;

  @override
  Future<void> markComplete() async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets(
    'AgriGuardianApp renders successfully on 360x800 narrow viewport',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = _FakeHttpClientAdapter();
      final fakeApiClient = ApiClient(
        accessTokenProvider: () async => 'fake_token',
        dio: dio,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeApiClient),
            onboardingStoreProvider.overrideWithValue(
              _CompletedOnboardingStore(),
            ),
          ],
          child: const AgriGuardianApp(),
        ),
      );

      // The app boots into the splash first - two scenes at 3s each -
      // then, because setup is already complete above, go_router replaces
      // it with Home. Bounded pumps only: pumpAndSettle never settles
      // here (a pre-existing, unrelated continuously-scheduled frame
      // elsewhere in the app), which is why this test uses fixed pumps.
      await tester.pump(); // mounts SplashScreen, starts its controller
      // Step forward in slices so each scene's auto-advance timer, the
      // PageView transition and the async store read all get their turn.
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.byType(HomeDashboardScreen).evaluate().isNotEmpty) break;
      }
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // default route transition settles

      expect(find.byType(HomeDashboardScreen), findsOneWidget);
    },
  );
}
