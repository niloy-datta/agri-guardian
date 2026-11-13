import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/router.dart';
import '../../../core/services/voice_service.dart';
import '../domain/voice_guide_content.dart';

final voiceGuideControllerProvider = Provider<VoiceGuideController>((ref) {
  final controller = VoiceGuideController(VoiceService(), appRouter);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Outcome of asking the guide to speak.
enum VoiceRunResult {
  /// Narration started (or the screen has no guide and a short fallback was
  /// spoken in the selected language).
  started,

  /// The device has no text-to-speech voice for the selected language. Nothing
  /// was spoken, so the caller can tell the user instead of using the wrong
  /// language.
  voiceUnavailable,
}

/// Drives the voice guide in the selected language (Bangla or English): reads
/// the current page, or walks the whole app page by page (navigating as it
/// goes).
///
/// Every run gets a session number. Starting a new run, or calling [stop],
/// bumps the number, so an older run exits at its next check instead of
/// talking over the new one. Narration also stops when the user navigates to
/// another page by hand; a tour is the only thing that changes pages on purpose.
class VoiceGuideController {
  VoiceGuideController(this._voice, this._router) {
    _router.routeInformationProvider.addListener(_onRouteChanged);
  }

  final VoiceService _voice;
  final GoRouter _router;
  int _session = 0;
  bool _touring = false;
  String? _narratingPath;

  ValueListenable<bool> get isSpeaking => _voice.isSpeaking;

  String get currentPath => _router.routeInformationProvider.value.uri.path;

  GuideScreen? get currentGuide => guideForPath(currentPath);

  /// Speaks the guide for the screen the user is on right now.
  Future<VoiceRunResult> readCurrentScreen({required bool isBangla}) async {
    if (!await _voice.selectLanguage(isBangla: isBangla)) {
      return VoiceRunResult.voiceUnavailable;
    }
    final guide = currentGuide;
    final session = await _beginSession(touring: false);
    _narratingPath = currentPath;
    if (guide == null) {
      await _speakLines([
        isBangla
            ? 'এই পাতার জন্য এখনো ভয়েস নির্দেশনা যুক্ত হয়নি। পুরো অ্যাপ ঘুরে শুনতে ভয়েস গাইড বোতাম চাপুন।'
            : 'There is no voice guide for this page yet. To hear the whole app, press the voice guide button.',
      ], session);
      return VoiceRunResult.started;
    }
    await _speakLines(guide.linesFor(isBangla: isBangla), session);
    return VoiceRunResult.started;
  }

  /// Visits each main screen in turn and speaks where things are and what to
  /// tap there. Ends on Home.
  Future<VoiceRunResult> startTour({required bool isBangla}) async {
    if (!await _voice.selectLanguage(isBangla: isBangla)) {
      return VoiceRunResult.voiceUnavailable;
    }
    final session = await _beginSession(touring: true);
    await _speakLines([
      isBangla
          ? 'ভয়েস গাইড শুরু হচ্ছে। আমি আপনাকে প্রতিটি পাতায় নিয়ে যাব, আর বলব কোথায় কী আছে।'
          : 'The voice guide is starting. I will take you to each page and tell you where things are.',
    ], session);

    for (final guide in tourGuides) {
      if (!_isActive(session)) return VoiceRunResult.started;
      _router.go(guide.navPath!);
      _narratingPath = guide.navPath;
      // Let the destination build before reading its guide.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!_isActive(session)) return VoiceRunResult.started;
      await _speakLines(guide.linesFor(isBangla: isBangla), session);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (!_isActive(session)) return VoiceRunResult.started;
    _router.go(RoutePaths.home);
    _narratingPath = RoutePaths.home;
    await _speakLines([
      isBangla ? 'পুরো ঘোরা শেষ। আবার শুনতে ভয়েস গাইড বোতাম চাপুন।' : 'The tour is finished. To listen again, press the voice guide button.',
    ], session);
    _touring = false;
    return VoiceRunResult.started;
  }

  /// Stops any guide that is speaking or touring.
  Future<void> stop() async {
    _session++;
    _touring = false;
    await _voice.stop();
  }

  /// Reads [lines] aloud in the selected language. If narration is already
  /// playing, this stops it instead (the same button acts as play/stop).
  Future<VoiceRunResult> speakLines(
    List<String> lines, {
    required bool isBangla,
  }) async {
    if (_voice.isSpeaking.value) {
      await stop();
      return VoiceRunResult.started;
    }
    if (!await _voice.selectLanguage(isBangla: isBangla)) {
      return VoiceRunResult.voiceUnavailable;
    }
    final session = await _beginSession(touring: false);
    _narratingPath = currentPath;
    await _speakLines(lines, session);
    return VoiceRunResult.started;
  }

  Future<int> _beginSession({required bool touring}) async {
    _session++;
    final session = _session;
    _touring = touring;
    await _voice.stop();
    return session;
  }

  bool _isActive(int session) => session == _session;

  Future<void> _speakLines(List<String> lines, int session) async {
    for (final line in lines) {
      if (!_isActive(session)) return;
      await _voice.speak(line);
    }
  }

  /// Playback policy: when the user leaves the page being narrated by hand,
  /// stop talking about a page they are no longer looking at.
  void _onRouteChanged() {
    if (_touring || !_voice.isSpeaking.value) return;
    if (currentPath != _narratingPath) stop();
  }

  void dispose() {
    _session++;
    _router.routeInformationProvider.removeListener(_onRouteChanged);
    _voice.dispose();
  }
}
