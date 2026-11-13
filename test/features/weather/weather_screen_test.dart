import 'dart:async';

import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:agri_guardian/features/weather/application/weather_providers.dart';
import 'package:agri_guardian/features/weather/data/weather_risk_repository.dart';
import 'package:agri_guardian/features/weather/domain/weather_risk_models.dart';
import 'package:agri_guardian/features/weather/presentation/screens/weather_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed clock so forecast dates are deterministic.

/// Matches the app's own localization setup: Bangla numerals and copy for
/// `bn`, ASCII and English copy for `en`.
bool _containsBangla(String text) => RegExp('[\u0980-\u09FF]').hasMatch(text);

/// Every rendered Text in the tree, so a test can assert on the whole screen.
Iterable<String> _allTexts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');
DateTime _fixedNow() => DateTime(2026, 9, 28, 9);

class _FakeRepository implements WeatherRiskRepository {
  final List<Future<WeatherRiskSnapshot> Function()> _responses;
  int calls = 0;

  _FakeRepository(this._responses);

  @override
  Future<WeatherRiskSnapshot> fetchSnapshot() {
    final i = calls < _responses.length ? calls : _responses.length - 1;
    calls++;
    return _responses[i]();
  }
}

Future<WeatherRiskSnapshot> _demo() =>
    DemoWeatherRiskRepository(now: _fixedNow).fetchSnapshot();

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required WeatherRiskRepository repository,
    bool offline = false,
    Size size = const Size(420, 3200),
    bool reduceMotion = true,
    Locale locale = const Locale('bn'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherRiskRepositoryProvider.overrideWithValue(repository),
          weatherIsOfflineProvider.overrideWith((ref) => Stream.value(offline)),
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
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: const WeatherScreen(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the demo-data banner and demo origin chip', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _FakeRepository([_demo]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('weather-demo-banner')), findsOneWidget);
    expect(find.text('ডেমো ডেটা — লাইভ নয়'), findsOneWidget);
    expect(find.text('ডেমো'), findsWidgets);
    expect(find.text('আজ কী করবেন?'), findsOneWidget);
    expect(find.text('ডেমো নির্দেশনা'), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-alert')), findsOneWidget);
  });

  testWidgets('renders exactly seven forecast entries', (tester) async {
    await pumpScreen(tester, repository: _FakeRepository([_demo]));
    await tester.pumpAndSettle();

    final rows = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'weather-forecast-day-',
          ),
    );
    expect(rows, findsNWidgets(7));
    expect(find.text('আজ'), findsOneWidget);
  });

  testWidgets('shows the loading skeleton while the snapshot is pending', (
    tester,
  ) async {
    final pending = Completer<WeatherRiskSnapshot>();
    await pumpScreen(
      tester,
      repository: _FakeRepository([() => pending.future]),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('weather-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-hero')), findsNothing);
  });

  testWidgets('shows the error state and recovers on retry', (tester) async {
    final repository = _FakeRepository([
      () => Future.error(Exception('boom')),
      _demo,
    ]);
    await pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('weather-error')), findsOneWidget);
    expect(find.text('আবহাওয়ার তথ্য আনা যায়নি'), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-hero')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('weather-retry')));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.byKey(const ValueKey('weather-error')), findsNothing);
    expect(find.byKey(const ValueKey('weather-hero')), findsOneWidget);
  });

  testWidgets('offline banner does not call demo values previously fetched', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _FakeRepository([_demo]),
      offline: true,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('weather-offline-banner')),
      findsOneWidget,
    );
    expect(find.text('আপনি অফলাইনে আছেন'), findsOneWidget);
    expect(
      find.text('নিচের মানগুলো ডেমো নমুনা — আগে আনা কোনো ডেটা নয়।'),
      findsOneWidget,
    );
  });

  testWidgets('cached snapshot shows the cached banner, not the demo one', (
    tester,
  ) async {
    Future<WeatherRiskSnapshot> cached() async {
      final d = await _demo();
      return WeatherRiskSnapshot(
        origin: WeatherDataOrigin.cached,
        fieldLabel: d.fieldLabel,
        retrievedAt: DateTime(2026, 9, 27, 18, 5),
        current: d.current,
        rainfall: d.rainfall,
        hazards: d.hazards,
        forecast: d.forecast,
        irrigation: d.irrigation,
        alert: d.alert,
        sources: d.sources,
      );
    }

    await pumpScreen(tester, repository: _FakeRepository([cached]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('weather-cached-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('weather-demo-banner')), findsNothing);
    expect(find.text('ডেমো নির্দেশনা'), findsNothing);
  });

  testWidgets('never claims live NASA/GPM data and shows no fake timestamp', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _FakeRepository([_demo]));
    await tester.pumpAndSettle();

    expect(find.textContaining('LIVE'), findsNothing);
    expect(find.textContaining('NASA'), findsNothing);
    expect(find.textContaining('GPM'), findsNothing);
    expect(find.text('লাইভ'), findsNothing);
    expect(find.text('প্রযোজ্য নয় — কোথাও থেকে আনা হয়নি'), findsOneWidget);
    expect(find.text('সংযুক্ত নয়'), findsWidgets);
    expect(find.text('সংযুক্ত'), findsNothing);
  });

  testWidgets('lays out without overflow on a small phone with motion on', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _FakeRepository([_demo]),
      size: const Size(320, 2600),
      reduceMotion: false,
    );
    // Ambient hero/alert animations repeat forever, so pump fixed frames
    // instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('weather-hero')), findsOneWidget);

    // Dispose the repeating controllers before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('English UI shows only English copy for the demo screen', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _FakeRepository([_demo]),
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weather Risk Center'), findsOneWidget);
    expect(find.text('Demo data — not live'), findsOneWidget);
    expect(find.text('Demo'), findsWidgets);
    expect(find.text('What to do today?'), findsOneWidget);
    expect(find.text('Demo guidance'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Data & evidence'), findsOneWidget);
    expect(find.text('7-day forecast'), findsOneWidget);
    expect(find.text('Not connected'), findsWidgets);
    expect(
      find.text('Not applicable — not fetched from anywhere'),
      findsOneWidget,
    );

    // No Bangla anywhere in English mode, and no Bangla-English pairs.
    final bangla = _allTexts(tester).where(_containsBangla);
    expect(bangla, isEmpty, reason: 'English UI leaked Bangla: $bangla');
  });

  testWidgets('Bangla UI shows only Bangla copy (no English pairs)', (
    tester,
  ) async {
    await pumpScreen(tester, repository: _FakeRepository([_demo]));
    await tester.pumpAndSettle();

    expect(find.text('আবহাওয়া ঝুঁকি কেন্দ্র'), findsOneWidget);
    expect(find.text('Weather Risk Center'), findsNothing);
    expect(find.text('Demo data — not live'), findsNothing);
    expect(find.text('Data & evidence'), findsNothing);

    // Every visible text should be Bangla, numerals or Bangla-free symbols.
    // Only the Latin brand/source identifiers below are allowed.
    const allowedLatin = {'Mukti demo sample'};
    final latin = _allTexts(tester).where(
      (t) =>
          t.isNotEmpty && !_containsBangla(t) && RegExp('[A-Za-z]').hasMatch(t),
    );
    expect(
      latin.where((t) => !allowedLatin.contains(t)),
      isEmpty,
      reason: 'Bangla UI shows untranslated English: $latin',
    );
  });

  testWidgets('switching locale rebuilds the same demo snapshot', (
    tester,
  ) async {
    final repository = _FakeRepository([_demo]);
    await pumpScreen(
      tester,
      repository: repository,
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weather Risk Center'), findsOneWidget);

    await pumpScreen(tester, repository: repository);
    await tester.pumpAndSettle();
    expect(find.text('আবহাওয়া ঝুঁকি কেন্দ্র'), findsOneWidget);
    // Origin does not change with language: still demo, never live.
    expect(find.byKey(const ValueKey('weather-demo-banner')), findsOneWidget);
    expect(find.text('লাইভ'), findsNothing);
  });

  testWidgets('English offline banner keeps demo values described as demo', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      repository: _FakeRepository([_demo]),
      offline: true,
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsOneWidget);
    expect(
      find.text('Values below are demo samples, not data fetched earlier.'),
      findsOneWidget,
    );
  });

  test('demo repository is deterministic and never timestamped', () async {
    final a = await _demo();
    final b = await _demo();

    expect(a.origin, WeatherDataOrigin.demo);
    expect(a.retrievedAt, isNull);
    expect(a.forecast, hasLength(7));
    expect(a.forecast.first.date, DateTime(2026, 9, 28));
    expect(
      a.sources.where((s) => s.status == EvidenceSourceStatus.connected),
      isEmpty,
    );
    expect(
      [for (final d in a.forecast) d.rainProbabilityPercent],
      [for (final d in b.forecast) d.rainProbabilityPercent],
    );
  });
}
