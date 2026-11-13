import 'package:agri_guardian/core/services/voice_service.dart';
import 'package:agri_guardian/features/voice_guide/application/voice_guide_controller.dart';
import 'package:agri_guardian/features/voice_guide/domain/voice_guide_content.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

final _bangla = RegExp('[ঀ-৿]');

/// Fake engine: records what was spoken and in which language, and reports
/// completion right away so narration runs without a device.
class _FakeTts implements FlutterTts {
  _FakeTts({required this.installed});

  final Set<String> installed;
  final List<String> spoken = [];
  final List<String> languageSet = [];
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
  Future<dynamic> setLanguage(String language) async {
    languageSet.add(language);
    return 1;
  }

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

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SizedBox()),
    GoRoute(path: '/fields', builder: (_, _) => const SizedBox()),
  ],
);

void main() {
  group('guide content in both languages', () {
    test('every screen has the same number of Bangla and English lines', () {
      for (final guide in screenGuides) {
        expect(
          guide.linesEn.length,
          guide.lines.length,
          reason: '${guide.title} has mismatched line counts',
        );
        expect(guide.linesEn, isNotEmpty, reason: guide.title);
      }
    });

    test(
      'Bangla lines are Bangla; English lines and titles have no Bangla',
      () {
        for (final guide in screenGuides) {
          for (final line in guide.lines) {
            expect(
              _bangla.hasMatch(line),
              isTrue,
              reason: '${guide.title}: $line',
            );
          }
          expect(
            _bangla.hasMatch(guide.titleEn),
            isFalse,
            reason: guide.titleEn,
          );
          for (final line in guide.linesEn) {
            expect(
              _bangla.hasMatch(line),
              isFalse,
              reason: '${guide.titleEn}: $line',
            );
          }
        }
      },
    );

    test('linesFor and titleFor pick the requested language', () {
      final home = guideForPath('/')!;
      expect(home.titleFor(isBangla: true), home.title);
      expect(home.titleFor(isBangla: false), home.titleEn);
      expect(home.linesFor(isBangla: false), home.linesEn);
    });
  });

  group('narration', () {
    testWidgets('English run speaks English with an English voice', (
      tester,
    ) async {
      final tts = _FakeTts(installed: {'en-US'});
      final controller = VoiceGuideController(
        VoiceService(tts: tts),
        _router(),
      );

      final result = await controller.readCurrentScreen(isBangla: false);

      expect(result, VoiceRunResult.started);
      expect(tts.languageSet, ['en-US']);
      expect(tts.spoken, guideForPath('/')!.linesEn);
      expect(tts.spoken.any((line) => _bangla.hasMatch(line)), isFalse);
      controller.dispose();
    });

    testWidgets('Bangla run speaks Bangla with a Bangla voice', (tester) async {
      final tts = _FakeTts(installed: {'bn-BD'});
      final controller = VoiceGuideController(
        VoiceService(tts: tts),
        _router(),
      );

      final result = await controller.readCurrentScreen(isBangla: true);

      expect(result, VoiceRunResult.started);
      expect(tts.languageSet, ['bn-BD']);
      expect(tts.spoken, guideForPath('/')!.lines);
      controller.dispose();
    });

    testWidgets('missing Bangla voice speaks nothing and reports it', (
      tester,
    ) async {
      // English is installed, Bangla is not: a Bangla run must not fall back
      // to speaking Bangla text with the English voice.
      final tts = _FakeTts(installed: {'en-US'});
      final controller = VoiceGuideController(
        VoiceService(tts: tts),
        _router(),
      );

      final result = await controller.readCurrentScreen(isBangla: true);

      expect(result, VoiceRunResult.voiceUnavailable);
      expect(tts.spoken, isEmpty);
      controller.dispose();
    });

    testWidgets('missing English voice speaks nothing and reports it', (
      tester,
    ) async {
      final tts = _FakeTts(installed: {'bn-BD'});
      final controller = VoiceGuideController(
        VoiceService(tts: tts),
        _router(),
      );

      final result = await controller.readCurrentScreen(isBangla: false);

      expect(result, VoiceRunResult.voiceUnavailable);
      expect(tts.spoken, isEmpty);
      controller.dispose();
    });

    testWidgets('switching language switches the voice for the next run', (
      tester,
    ) async {
      final tts = _FakeTts(installed: {'bn-BD', 'en-US'});
      final controller = VoiceGuideController(
        VoiceService(tts: tts),
        _router(),
      );

      await controller.readCurrentScreen(isBangla: true);
      await controller.readCurrentScreen(isBangla: false);

      expect(tts.languageSet, ['bn-BD', 'en-US']);
      expect(tts.spoken.last, guideForPath('/')!.linesEn.last);
      controller.dispose();
    });

    testWidgets('a page with no guide speaks a fallback in the same language', (
      tester,
    ) async {
      final tts = _FakeTts(installed: {'en-US'});
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
        initialLocation: '/no-guide-here',
      );
      final controller = VoiceGuideController(VoiceService(tts: tts), router);

      final result = await controller.readCurrentScreen(isBangla: false);

      expect(result, VoiceRunResult.started);
      expect(tts.spoken, hasLength(1));
      expect(_bangla.hasMatch(tts.spoken.single), isFalse);
      controller.dispose();
    });
  });
}
