import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:agri_guardian/core/services/voice_service.dart';
import 'package:agri_guardian/features/voice_guide/application/voice_guide_controller.dart';
import 'package:agri_guardian/screens/treatment_plan.dart';
import 'package:agri_guardian/shared/demo/showcase_story.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

final _bangla = RegExp('[ঀ-৿]');

/// Fake text-to-speech engine: records spoken text and completes at once.
class _FakeTts implements FlutterTts {
  _FakeTts({required this.installed});

  final Set<String> installed;
  final List<String> spoken = [];
  VoidCallback? _onDone;

  @override
  void setCompletionHandler(VoidCallback callback) => _onDone = callback;

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setErrorHandler(ErrorHandler handler) {}

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      installed.contains(language);

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    Future.microtask(() => _onDone?.call());
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Iterable<String> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');

Future<_FakeTts> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('bn'),
  Set<String> voices = const {},
  Size size = const Size(420, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final tts = _FakeTts(installed: voices);
  final controller = VoiceGuideController(
    VoiceService(tts: tts),
    GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    ),
  );
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [voiceGuideControllerProvider.overrideWithValue(controller)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const TreatmentPlanScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tts;
}

void main() {
  testWidgets('Bangla: Bangla plan, timeline and disclaimer, no English UI', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('৭ দিনের ব্যবস্থাপনা পরিকল্পনা'), findsOneWidget);
    expect(find.text('কর্মপরিকল্পনা টাইমলাইন'), findsOneWidget);
    expect(find.text('আজ • ১ম দিন'), findsOneWidget);
    expect(find.text('দিন ২–৩'), findsOneWidget);
    expect(find.text('দিন ৫–৭'), findsOneWidget);
    expect(find.text('পরিকল্পিত'), findsOneWidget);
    expect(find.text('৪৮ ঘণ্টা বাকি'), findsOneWidget);
    expect(find.textContaining('ডেমো নমুনা'), findsOneWidget);

    final english = _texts(tester).where(
      (t) =>
          t.isNotEmpty &&
          !_bangla.hasMatch(t) &&
          RegExp('[A-Za-z]').hasMatch(t) &&
          t != DemoStory.diagnosis.pathogen &&
          !t.contains('%'),
    );
    expect(english, isEmpty, reason: 'English leaked into Bangla UI: $english');
  });

  testWidgets('English: English plan and timeline, no Bangla text', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('en'));

    expect(find.text('7-day management plan'), findsOneWidget);
    expect(find.text('Action timeline'), findsOneWidget);
    expect(find.text('Today • Day 1'), findsOneWidget);
    expect(find.text('Days 2–3'), findsOneWidget);
    expect(find.text('Days 5–7'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('48 hours left'), findsOneWidget);

    final bangla = _texts(tester).where(_bangla.hasMatch);
    expect(bangla, isEmpty, reason: 'Bangla leaked into English UI: $bangla');
  });

  testWidgets('dosage and timing are unchanged in both languages', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.textContaining('০.৭৫ গ্রাম গুলে বিকেলে'), findsOneWidget);

    await _pump(tester, locale: const Locale('en'));
    expect(find.textContaining('0.75 g'), findsOneWidget);
    expect(find.textContaining('afternoon'), findsWidgets);
  });

  testWidgets(
    'start plan shows an honest demo dialog, not a fake active plan',
    (tester) async {
      await _pump(tester);

      await tester.tap(find.text('পরিকল্পনা শুরু করুন →'));
      await tester.pumpAndSettle();

      expect(find.text('ডেমো পরিকল্পনা'), findsOneWidget);
      expect(
        find.text(
          'এটি একটি ডেমো পরিকল্পনা। ট্র্যাকিং ও দৈনিক নোটিফিকেশন এখনো চালু হয়নি।',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('সক্রিয়!'), findsNothing);
      expect(find.textContaining('ট্র্যাকিং শুরু হয়েছে'), findsNothing);
    },
  );

  testWidgets('listen with no voice installed: says so, speaks nothing', (
    tester,
  ) async {
    final tts = await _pump(tester, locale: const Locale('en'));

    await tester.tap(find.text('Listen'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No English voice is installed on this device. Add an English text-to-speech voice in the device settings.',
      ),
      findsOneWidget,
    );
    expect(tts.spoken, isEmpty);
  });

  testWidgets('listen with a voice: speaks the plan in the selected language', (
    tester,
  ) async {
    final tts = await _pump(tester, voices: {'bn-BD'});

    await tester.tap(find.text('শুনুন'));
    await tester.pumpAndSettle();

    expect(tts.spoken, isNotEmpty);
    expect(tts.spoken.every((line) => _bangla.hasMatch(line)), isTrue);
    expect(tts.spoken, contains('জরুরি নিষ্কাশন ও নাইট্রোজেন স্থগিত'));
  });

  testWidgets('small phone: no layout overflow in either language', (
    tester,
  ) async {
    for (final locale in const [Locale('bn'), Locale('en')]) {
      await _pump(tester, locale: locale, size: const Size(320, 640));
      expect(tester.takeException(), isNull, reason: locale.languageCode);
    }
  });
}
