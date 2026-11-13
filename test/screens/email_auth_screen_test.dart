import 'dart:convert';
import 'dart:typed_data';

import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:agri_guardian/features/onboarding/application/onboarding_providers.dart';
import 'package:agri_guardian/features/onboarding/data/onboarding_store.dart';
import 'package:agri_guardian/features/onboarding/domain/onboarding_profile.dart';
import 'package:agri_guardian/screens/email_auth_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  ResponseBody Function(RequestOptions options)? onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (onFetch != null) return onFetch!(options);
    return ResponseBody.fromString(
      jsonEncode({'sent': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryOnboardingStore implements OnboardingStore {
  OnboardingProfile profile;
  bool complete;

  _MemoryOnboardingStore({
    this.profile = const OnboardingProfile(
      language: AppLanguage.bangla,
    ),
    this.complete = false,
  });

  @override
  Future<OnboardingProfile> read() async => profile;

  @override
  Future<void> write(OnboardingProfile profile) async => this.profile = profile;

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

void main() {
  late _TestAdapter adapter;
  late Dio dio;
  late _MemoryOnboardingStore store;

  setUp(() {
    adapter = _TestAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test-server/api/v1'))
      ..httpClientAdapter = adapter;
    store = _MemoryOnboardingStore();
  });

  Widget buildTestWidget({Locale locale = const Locale('bn')}) {
    return ProviderScope(
      overrides: [
        onboardingStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: EmailAuthScreen(dio: dio),
      ),
    );
  }

  group('EmailAuthScreen', () {
    testWidgets('renders login mode in Bangla by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('স্বাগতম'), findsOneWidget);
      expect(find.byKey(const Key('auth_email_input')), findsOneWidget);
      expect(find.byKey(const Key('auth_code_input')), findsNothing);
      expect(find.byKey(const Key('auth_mode_toggle_button')), findsOneWidget);
    });

    testWidgets('switches between login and registration modes', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('স্বাগতম'), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_mode_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.text('আপনার অ্যাকাউন্ট তৈরি করুন'), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_mode_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.text('স্বাগতম'), findsOneWidget);
    });

    testWidgets('switches language between Bangla and English via AppBar toggle', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('bn')));
      await tester.pumpAndSettle();

      expect(find.text('স্বাগতম'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // Tap language toggle
      await tester.tap(find.byKey(const Key('auth_language_toggle')));
      await tester.pumpAndSettle();

      // Should update store to English
      final updated = await store.read();
      expect(updated.language, AppLanguage.english);
    });

    testWidgets('shows validation error when email is empty or invalid', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Submit with empty email
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(
        find.byKey(const Key('auth_email_input')),
        'invalid-email',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('requests verification code on valid email submission', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_email_input')),
        'farmer@example.com',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.path, '/auth/email/request');
      expect(
        adapter.lastRequest!.data,
        equals({'email': 'farmer@example.com', 'mode': 'login'}),
      );

      // Code field should now appear
      expect(find.byKey(const Key('auth_code_input')), findsOneWidget);
      expect(find.byKey(const Key('auth_resend_button')), findsOneWidget);
    });

    testWidgets('shows validation error if code is less than 6 digits', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_email_input')),
        'farmer@example.com',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      // Enter 4 digits instead of 6
      await tester.enterText(find.byKey(const Key('auth_code_input')), '1234');
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the 6-digit code'), findsOneWidget);
    });

    testWidgets('handles server error response cleanly', (tester) async {
      adapter.onFetch = (options) {
        return ResponseBody.fromString(
          jsonEncode({'detail': 'Account not found; create one first'}),
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      await tester.pumpWidget(buildTestWidget(locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_email_input')),
        'unknown@example.com',
      );
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Account not found; create one first'),
        findsOneWidget,
      );
    });
  });
}
