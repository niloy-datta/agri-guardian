import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for the in-app voice guide, in Bangla or English.
///
/// Call [selectLanguage] before speaking: it picks an installed voice for the
/// language and returns false when none exists, so the caller can tell the
/// user instead of speaking in the wrong language. Speaks one utterance at a
/// time: a new [speak] cancels whatever is still playing.
class VoiceService {
  VoiceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  /// Locale candidates in preference order.
  static const banglaLocales = ['bn-BD', 'bn-IN'];
  static const englishLocales = ['en-US', 'en-GB', 'en-IN'];

  final FlutterTts _tts;
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  Future<void>? _ready;
  Completer<void>? _pending;
  String? _selected;

  /// Longest single utterance we wait for before moving on, so a TTS engine
  /// that never reports completion cannot freeze the guide.
  static const _maxUtterance = Duration(seconds: 45);

  Future<void> _init() => _ready ??= _configure();

  Future<void> _configure() async {
    try {
      _tts.setCompletionHandler(_finishPending);
      _tts.setCancelHandler(_finishPending);
      _tts.setErrorHandler((_) => _finishPending());

      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (error, stackTrace) {
      debugPrint('VoiceService: TTS setup failed: $error\n$stackTrace');
    }
  }

  /// Selects an installed voice for the language. Returns false when the
  /// device has no voice for it, in which case nothing should be spoken.
  Future<bool> selectLanguage({required bool isBangla}) async {
    await _init();
    final candidates = isBangla ? banglaLocales : englishLocales;
    for (final locale in candidates) {
      if (await _isAvailable(locale)) {
        if (_selected != locale) {
          try {
            await _tts.setLanguage(locale);
            _selected = locale;
          } catch (error) {
            debugPrint('VoiceService: setLanguage($locale) failed: $error');
            continue;
          }
        }
        return true;
      }
    }
    return false;
  }

  Future<bool> _isAvailable(String locale) async {
    try {
      final available = await _tts.isLanguageAvailable(locale);
      return available == true || available == 1;
    } catch (_) {
      return false;
    }
  }

  /// Speaks [text] in the language chosen by [selectLanguage] and completes
  /// when the utterance finishes or is stopped.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _init();
    await _cancelCurrent();

    final completer = Completer<void>();
    _pending = completer;
    isSpeaking.value = true;
    try {
      await _tts.speak(trimmed);
      await completer.future.timeout(_maxUtterance, onTimeout: () {});
    } catch (error) {
      debugPrint('VoiceService: speak failed: $error');
    } finally {
      if (identical(_pending, completer)) _pending = null;
      isSpeaking.value = false;
    }
  }

  /// Stops any speech in progress.
  Future<void> stop() async {
    await _cancelCurrent();
    isSpeaking.value = false;
  }

  Future<void> _cancelCurrent() async {
    _finishPending();
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('VoiceService: stop failed: $error');
    }
  }

  void _finishPending() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void dispose() {
    _finishPending();
    _tts.stop();
    isSpeaking.dispose();
  }
}
