/// UI/domain contract for the AI farm assistant.
///
/// No LLM or speech backend exists yet. Every answer therefore states its
/// [AnswerOrigin] explicitly, so a demo or "not connected" reply can never
/// render as if it came from live intelligence.
library;

/// The assistant's current interaction phase, driving the orb, the mic
/// control and the status line.
enum AssistantPhase {
  idle,

  /// A real voice input is capturing speech. Never entered while no
  /// speech implementation is connected.
  listening,

  /// Waiting for the answer engine to respond.
  processing,

  /// The latest answer is on screen.
  answering,

  error,
}

enum AnswerOrigin {
  /// From a connected assistant backend.
  live,

  /// Hand-written, on-device sample answer for demonstration only.
  demo,

  /// No source could answer - the live assistant is not connected.
  notConnected,
}

enum EvidenceKind { connected, demo, notConnected }

class AnswerEvidence {
  final String labelBn;
  final EvidenceKind kind;

  const AnswerEvidence({required this.labelBn, required this.kind});
}

/// In-app screens an answer or quick action can open.
enum AssistantDestination { scan, weather, fields, market }

class AssistantAction {
  final String labelBn;
  final AssistantDestination destination;

  const AssistantAction({required this.labelBn, required this.destination});
}

class AssistantAnswer {
  final AnswerOrigin origin;
  final String directAnswerBn;
  final String? reasonBn;
  final List<AnswerEvidence> evidence;
  final String? nextStepBn;
  final List<AssistantAction> actions;

  const AssistantAnswer({
    required this.origin,
    required this.directAnswerBn,
    this.reasonBn,
    this.evidence = const [],
    this.nextStepBn,
    this.actions = const [],
  });
}

sealed class ChatMessage {
  final int id;
  const ChatMessage(this.id);
}

class FarmerMessage extends ChatMessage {
  final String text;

  /// Device-clock time the farmer sent it - a true local timestamp.
  final DateTime sentAt;
  final bool viaVoice;

  const FarmerMessage({
    required int id,
    required this.text,
    required this.sentAt,
    this.viaVoice = false,
  }) : super(id);
}

class AssistantReply extends ChatMessage {
  final AssistantAnswer answer;

  const AssistantReply({required int id, required this.answer}) : super(id);
}

/// The answer engine failed for [question]; the UI offers a retry.
class AssistantFailure extends ChatMessage {
  final String question;

  const AssistantFailure({required int id, required this.question})
    : super(id);
}

class AssistantState {
  final AssistantPhase phase;
  final List<ChatMessage> messages;

  /// Explanation for [AssistantPhase.error] (e.g. voice not connected).
  final String? errorBn;

  const AssistantState({
    this.phase = AssistantPhase.idle,
    this.messages = const [],
    this.errorBn,
  });

  bool get isBusy =>
      phase == AssistantPhase.listening || phase == AssistantPhase.processing;

  AssistantState copyWith({
    AssistantPhase? phase,
    List<ChatMessage>? messages,
    String? errorBn,
  }) {
    return AssistantState(
      phase: phase ?? this.phase,
      messages: messages ?? this.messages,
      errorBn: errorBn,
    );
  }
}
