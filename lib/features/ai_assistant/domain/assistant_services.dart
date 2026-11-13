import 'assistant_models.dart';

/// Answers a farmer's question. A future implementation calls a FastAPI
/// assistant endpoint and returns [AnswerOrigin.live]; none exists yet.
abstract interface class AssistantAnswerEngine {
  Future<AssistantAnswer> answer(String question);
}

/// Captures one spoken question. A future implementation wraps a real
/// speech-recognition plugin; none is in the app yet.
abstract interface class AssistantVoiceInput {
  /// False when no speech recognition is connected - the UI must then
  /// explain that instead of pretending to listen.
  bool get isAvailable;

  /// Listens once and returns the recognised text, or null if nothing
  /// was recognised / the user cancelled.
  Future<String?> listen();
}
