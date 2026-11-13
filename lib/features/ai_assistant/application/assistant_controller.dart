import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/fields/application/fields_providers.dart'
    show connectivityServiceProvider;
import '../data/demo_assistant_engine.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_services.dart';

/// Demo-only until an assistant backend exists. Replace this provider
/// with a real engine later; the controller and UI read only the
/// [AssistantAnswerEngine] contract.
final assistantAnswerEngineProvider = Provider<AssistantAnswerEngine>((ref) {
  return const DemoAssistantAnswerEngine();
});

/// No speech recognition is connected yet - see [UnavailableVoiceInput].
final assistantVoiceInputProvider = Provider<AssistantVoiceInput>((ref) {
  return const UnavailableVoiceInput();
});

/// Injectable clock so farmer-message timestamps are testable.
final assistantClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// True while the device has no usable network interface. Reuses the
/// app-wide [connectivityServiceProvider].
final assistantIsOfflineProvider = StreamProvider.autoDispose<bool>((
  ref,
) async* {
  final connectivity = ref.watch(connectivityServiceProvider);
  yield !await connectivity.isConnected();
  yield* connectivity.onConnectivityChanged().map((connected) => !connected);
});

class AssistantController extends AutoDisposeNotifier<AssistantState> {
  int _nextId = 0;

  @override
  AssistantState build() => const AssistantState();

  /// Sends a typed, suggested, or recognised question.
  Future<void> ask(String question, {bool viaVoice = false}) async {
    final text = question.trim();
    if (text.isEmpty || state.phase == AssistantPhase.processing) return;

    final farmer = FarmerMessage(
      id: _nextId++,
      text: text,
      sentAt: ref.read(assistantClockProvider)(),
      viaVoice: viaVoice,
    );
    state = state.copyWith(
      phase: AssistantPhase.processing,
      messages: [...state.messages, farmer],
    );
    await _resolve(text);
  }

  /// Re-asks the question behind a failed reply, replacing that failure.
  Future<void> retry(AssistantFailure failure) async {
    if (state.phase == AssistantPhase.processing) return;
    state = state.copyWith(
      phase: AssistantPhase.processing,
      messages: [
        for (final m in state.messages)
          if (m.id != failure.id) m,
      ],
    );
    await _resolve(failure.question);
  }

  Future<void> _resolve(String question) async {
    try {
      final answer = await ref
          .read(assistantAnswerEngineProvider)
          .answer(question);
      state = state.copyWith(
        phase: AssistantPhase.answering,
        messages: [
          ...state.messages,
          AssistantReply(id: _nextId++, answer: answer),
        ],
      );
    } catch (_) {
      state = state.copyWith(
        phase: AssistantPhase.error,
        errorBn: 'উত্তর আনা যায়নি। আবার চেষ্টা করুন।',
        messages: [
          ...state.messages,
          AssistantFailure(id: _nextId++, question: question),
        ],
      );
    }
  }

  /// Starts one voice capture - or explains that voice is not connected.
  Future<void> startVoice() async {
    if (state.isBusy) return;
    final voice = ref.read(assistantVoiceInputProvider);
    if (!voice.isAvailable) {
      state = state.copyWith(
        phase: AssistantPhase.error,
        errorBn: 'ভয়েস ইনপুট এখনো সংযুক্ত হয়নি। প্রশ্ন লিখুন বা নিচে থেকে বেছে নিন।',
      );
      return;
    }

    state = state.copyWith(phase: AssistantPhase.listening);
    try {
      final text = await voice.listen();
      if (text == null || text.trim().isEmpty) {
        state = state.copyWith(
          phase: AssistantPhase.error,
          errorBn: 'কিছু শোনা যায়নি। আবার বলুন।',
        );
        return;
      }
      state = state.copyWith(phase: AssistantPhase.idle);
      await ask(text, viaVoice: true);
    } catch (_) {
      state = state.copyWith(
        phase: AssistantPhase.error,
        errorBn: 'ভয়েস শোনা যায়নি। আবার চেষ্টা করুন।',
      );
    }
  }

  void clearConversation() {
    if (state.phase == AssistantPhase.processing) return;
    state = const AssistantState();
  }
}

final assistantControllerProvider =
    AutoDisposeNotifierProvider<AssistantController, AssistantState>(
      AssistantController.new,
    );
