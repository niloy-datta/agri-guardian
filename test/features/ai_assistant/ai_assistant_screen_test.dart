import 'dart:async';

import 'package:agri_guardian/features/ai_assistant/application/assistant_controller.dart';
import 'package:agri_guardian/features/ai_assistant/data/demo_assistant_engine.dart';
import 'package:agri_guardian/features/ai_assistant/domain/assistant_models.dart';
import 'package:agri_guardian/features/ai_assistant/domain/assistant_services.dart';
import 'package:agri_guardian/features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import 'package:agri_guardian/features/ai_assistant/presentation/widgets/assistant_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

DateTime _fixedNow() => DateTime(2026, 9, 28, 9, 15);

class _ScriptedEngine implements AssistantAnswerEngine {
  final List<Future<AssistantAnswer> Function(String q)> _steps;
  int calls = 0;

  _ScriptedEngine(this._steps);

  @override
  Future<AssistantAnswer> answer(String question) {
    final i = calls < _steps.length ? calls : _steps.length - 1;
    calls++;
    return _steps[i](question);
  }
}

class _FakeVoice implements AssistantVoiceInput {
  final Completer<String?> completer = Completer();

  @override
  bool get isAvailable => true;

  @override
  Future<String?> listen() => completer.future;
}

Future<AssistantAnswer> _demo(String q) =>
    const DemoAssistantAnswerEngine().answer(q);

Widget _app({
  required Widget home,
  AssistantAnswerEngine? engine,
  AssistantVoiceInput? voice,
  bool offline = false,
  bool reduceMotion = true,
}) {
  return ProviderScope(
    overrides: [
      assistantAnswerEngineProvider.overrideWithValue(
        engine ?? const DemoAssistantAnswerEngine(),
      ),
      if (voice != null) assistantVoiceInputProvider.overrideWithValue(voice),
      assistantClockProvider.overrideWithValue(_fixedNow),
      assistantIsOfflineProvider.overrideWith((ref) => Stream.value(offline)),
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: home,
      ),
    ),
  );
}

void main() {
  void setSurface(WidgetTester tester, [Size size = const Size(420, 2400)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    AssistantAnswerEngine? engine,
    AssistantVoiceInput? voice,
    bool offline = false,
  }) async {
    setSurface(tester);
    await tester.pumpWidget(
      _app(
        home: const MaterialApp(home: AiAssistantScreen()),
        engine: engine,
        voice: voice,
        offline: offline,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state: hero, demo badge, suggestions, quick actions', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('assistant-hero')), findsOneWidget);
    expect(find.text('স্বাগতম, কৃষক বন্ধু'), findsOneWidget);
    expect(find.text('ডেমো মোড · লাইভ AI সংযুক্ত নয়'), findsOneWidget);
    for (final q in assistantSuggestedQuestions) {
      expect(find.text(q), findsOneWidget);
    }
    for (final d in AssistantDestination.values) {
      expect(find.byKey(ValueKey('assistant-quick-${d.name}')), findsOneWidget);
    }
    expect(find.text('প্রশ্ন করতে মাইক চাপুন বা লিখুন'), findsOneWidget);
  });

  testWidgets('suggested question yields a labelled structured demo answer', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('আজ সেচ দেব?'));
    await tester.pumpAndSettle();

    // Farmer bubble with a true device-clock timestamp.
    expect(find.text('আজ সেচ দেব?'), findsWidgets);
    expect(find.text('০৯:১৫'), findsOneWidget);

    expect(find.text('ডেমো উত্তর · যাচাই করা নয়'), findsOneWidget);
    expect(find.text('কারণ'), findsOneWidget);
    expect(find.text('প্রমাণ ও উৎস'), findsOneWidget);
    expect(find.text('ডেমো আবহাওয়া নমুনা'), findsOneWidget);
    expect(find.text('লাইভ AI সংযুক্ত নয়'), findsOneWidget);
    expect(find.text('পরবর্তী পদক্ষেপ'), findsOneWidget);
    expect(find.text('আবহাওয়া দেখুন'), findsOneWidget);
    expect(find.text('উত্তর প্রস্তুত · আরও জিজ্ঞেস করুন'), findsOneWidget);
  });

  testWidgets('unmatched typed question says the live assistant is absent', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('assistant-input')),
      'সারের দাম?',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await tester.pumpAndSettle();

    // 'দাম' matches the market answer - still demo, never a price.
    expect(find.text('লাইভ বাজারদর ছাড়া বিক্রির সঠিক সময় বলা যায় না।'),
        findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('assistant-input')),
      'হ্যালো',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await tester.pumpAndSettle();

    expect(find.text('লাইভ সহকারী সংযুক্ত নয়'), findsOneWidget);
    expect(find.text('এই প্রশ্নের উত্তর এখন দিতে পারছি না।'), findsOneWidget);
  });

  testWidgets('mic explains voice is not connected and never "listens"', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('assistant-mic')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'ভয়েস ইনপুট এখনো সংযুক্ত হয়নি। প্রশ্ন লিখুন বা নিচে থেকে বেছে নিন।',
      ),
      findsOneWidget,
    );
    expect(find.text('শুনছি… বলুন'), findsNothing);
  });

  testWidgets('a connected voice input drives listening, then answers', (
    tester,
  ) async {
    final voice = _FakeVoice();
    await pumpScreen(tester, voice: voice);

    await tester.tap(find.byKey(const ValueKey('assistant-mic')));
    await tester.pump();
    expect(find.text('শুনছি… বলুন'), findsOneWidget);

    voice.completer.complete('বৃষ্টি হওয়ার সম্ভাবনা?');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
    expect(
      find.text('ডেমো পূর্বাভাসে বৃষ্টির সম্ভাবনা বেশি দেখানো হয়েছে।'),
      findsOneWidget,
    );
  });

  testWidgets('processing state shows the thinking card', (tester) async {
    final pending = Completer<AssistantAnswer>();
    await pumpScreen(tester, engine: _ScriptedEngine([(_) => pending.future]));

    await tester.tap(find.text('আজ সেচ দেব?'));
    await tester.pump();

    expect(find.byKey(const ValueKey('assistant-thinking')), findsOneWidget);
    expect(find.text('ভাবছি…'), findsWidgets);

    pending.complete(await _demo('আজ সেচ দেব?'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-thinking')), findsNothing);
    expect(find.text('ডেমো উত্তর · যাচাই করা নয়'), findsOneWidget);
  });

  testWidgets('engine failure shows error card and retry recovers', (
    tester,
  ) async {
    final engine = _ScriptedEngine([
      (_) => Future.error(Exception('down')),
      _demo,
    ]);
    await pumpScreen(tester, engine: engine);

    await tester.tap(find.text('বৃষ্টি হওয়ার সম্ভাবনা?'));
    await tester.pumpAndSettle();

    expect(find.text('উত্তর আনা যায়নি'), findsOneWidget);
    expect(find.text('উত্তর আনা যায়নি। আবার চেষ্টা করুন।'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assistant-retry')));
    await tester.pumpAndSettle();

    expect(engine.calls, 2);
    expect(find.text('উত্তর আনা যায়নি'), findsNothing);
    expect(find.text('ডেমো উত্তর · যাচাই করা নয়'), findsOneWidget);
  });

  testWidgets('offline banner is shown when the device is offline', (
    tester,
  ) async {
    await pumpScreen(tester, offline: true);

    expect(
      find.byKey(const ValueKey('assistant-offline-banner')),
      findsOneWidget,
    );
    expect(find.text('আপনি অফলাইনে আছেন'), findsOneWidget);
  });

  testWidgets('never claims live NASA/GPM intelligence', (tester) async {
    await pumpScreen(tester);
    // Typed rather than tapped: once chatting, later suggestion chips sit
    // off-screen in a horizontal list.
    for (final q in assistantSuggestedQuestions) {
      await tester.enterText(find.byKey(const ValueKey('assistant-input')), q);
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pumpAndSettle();
    }
    expect(find.text('ডেমো উত্তর · যাচাই করা নয়'), findsWidgets);

    expect(find.textContaining('LIVE'), findsNothing);
    expect(find.textContaining('NASA'), findsNothing);
    expect(find.textContaining('GPM'), findsNothing);
    expect(find.text('লাইভ উত্তর'), findsNothing);
  });

  testWidgets('quick actions and answer actions open real routes', (
    tester,
  ) async {
    setSurface(tester);
    final router = GoRouter(
      initialLocation: '/ai-assistant',
      routes: [
        GoRoute(
          path: '/ai-assistant',
          builder: (_, _) => const AiAssistantScreen(),
        ),
        GoRoute(path: '/weather', builder: (_, _) => const Text('WEATHER')),
        GoRoute(path: '/scan', builder: (_, _) => const Text('SCAN')),
        GoRoute(path: '/fields', builder: (_, _) => const Text('FIELDS')),
        GoRoute(path: '/market-price', builder: (_, _) => const Text('MARKET')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(home: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assistant-quick-scan')));
    await tester.pumpAndSettle();
    expect(find.text('SCAN'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assistant-quick-market')));
    await tester.pumpAndSettle();
    expect(find.text('MARKET'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('আজ সেচ দেব?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('আবহাওয়া দেখুন'));
    await tester.pumpAndSettle();
    expect(find.text('WEATHER'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assistant-quick-fields')));
    await tester.pumpAndSettle();
    expect(find.text('FIELDS'), findsOneWidget);
  });

  testWidgets('no overflow on a small phone with motion enabled', (
    tester,
  ) async {
    setSurface(tester, const Size(320, 640));
    await tester.pumpWidget(
      _app(
        home: const MaterialApp(home: AiAssistantScreen()),
        reduceMotion: false,
      ),
    );
    // The orb animates forever, so pump fixed frames instead of settling.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('আজ সেচ দেব?'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('ডেমো উত্তর · যাচাই করা নয়'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('demo engine: every suggested question gets a non-live answer', () async {
    for (final q in assistantSuggestedQuestions) {
      final a = await const DemoAssistantAnswerEngine().answer(q);
      expect(a.origin, AnswerOrigin.demo, reason: q);
    }
    final unknown = await const DemoAssistantAnswerEngine().answer('xyz');
    expect(unknown.origin, AnswerOrigin.notConnected);
    expect(const UnavailableVoiceInput().isAvailable, isFalse);
  });
}
