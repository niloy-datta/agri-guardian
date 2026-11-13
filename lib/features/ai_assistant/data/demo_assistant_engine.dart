import '../domain/assistant_models.dart';
import '../domain/assistant_services.dart';

/// Deterministic, on-device sample answers for demonstrating the UI.
///
/// Makes no network call and contains no measured or computed values:
/// every answer is [AnswerOrigin.demo] (or [AnswerOrigin.notConnected]
/// for questions it cannot match), and points the farmer to the in-app
/// screen that would hold real data instead of inventing a figure.
class DemoAssistantAnswerEngine implements AssistantAnswerEngine {
  const DemoAssistantAnswerEngine();

  static const _demoEvidence = AnswerEvidence(
    labelBn: 'ডেমো নমুনা',
    kind: EvidenceKind.demo,
  );

  static const _liveMissing = AnswerEvidence(
    labelBn: 'লাইভ AI সংযুক্ত নয়',
    kind: EvidenceKind.notConnected,
  );

  @override
  Future<AssistantAnswer> answer(String question) async {
    final q = question.trim();

    if (q.contains('সেচ')) {
      return const AssistantAnswer(
        origin: AnswerOrigin.demo,
        directAnswerBn: 'ডেমো নমুনা অনুযায়ী আজ সেচ স্থগিত রাখা যায়।',
        reasonBn:
            'আবহাওয়া পাতার ডেমো পূর্বাভাসে আগামী ২৪ ঘণ্টায় বৃষ্টির '
            'সম্ভাবনা বেশি দেখানো হয়েছে।',
        evidence: [
          AnswerEvidence(
            labelBn: 'ডেমো আবহাওয়া নমুনা',
            kind: EvidenceKind.demo,
          ),
          _liveMissing,
        ],
        nextStepBn: 'জমির নালা খোলা রাখুন এবং আবহাওয়া পাতা দেখুন।',
        actions: [
          AssistantAction(
            labelBn: 'আবহাওয়া দেখুন',
            destination: AssistantDestination.weather,
          ),
        ],
      );
    }

    if (q.contains('পাতা') || q.contains('রোগ')) {
      return const AssistantAnswer(
        origin: AnswerOrigin.demo,
        directAnswerBn: 'ছবি না দেখে পাতার সমস্যা বলা সম্ভব নয়।',
        reasonBn:
            'পাতার রোগ চিনতে গাছের পরিষ্কার ছবি দরকার। অনুমান করে বলা '
            'ক্ষতিকর হতে পারে।',
        evidence: [_demoEvidence],
        nextStepBn: 'আক্রান্ত পাতার কাছ থেকে একটি ছবি তুলুন।',
        actions: [
          AssistantAction(
            labelBn: 'গাছ স্ক্যান করুন',
            destination: AssistantDestination.scan,
          ),
        ],
      );
    }

    if (q.contains('বৃষ্টি')) {
      return const AssistantAnswer(
        origin: AnswerOrigin.demo,
        directAnswerBn: 'ডেমো পূর্বাভাসে বৃষ্টির সম্ভাবনা বেশি দেখানো হয়েছে।',
        reasonBn:
            'এটি আবহাওয়া পাতার নমুনা ডেটা — কোনো লাইভ পূর্বাভাস নয়।',
        evidence: [
          AnswerEvidence(
            labelBn: 'ডেমো আবহাওয়া নমুনা',
            kind: EvidenceKind.demo,
          ),
          AnswerEvidence(
            labelBn: 'লাইভ পূর্বাভাস সংযুক্ত নয়',
            kind: EvidenceKind.notConnected,
          ),
        ],
        nextStepBn: '৭ দিনের পূর্বাভাস ও ঝুঁকি দেখতে আবহাওয়া পাতা খুলুন।',
        actions: [
          AssistantAction(
            labelBn: 'আবহাওয়া দেখুন',
            destination: AssistantDestination.weather,
          ),
        ],
      );
    }

    if (q.contains('বিক্রি') || q.contains('দাম') || q.contains('বাজার')) {
      return const AssistantAnswer(
        origin: AnswerOrigin.demo,
        directAnswerBn: 'লাইভ বাজারদর ছাড়া বিক্রির সঠিক সময় বলা যায় না।',
        reasonBn:
            'সহকারী এখনো কোনো বাজারদর উৎসের সাথে যুক্ত নয়, তাই দাম '
            'অনুমান করা হবে না।',
        evidence: [
          AnswerEvidence(
            labelBn: 'বাজারদর সংযুক্ত নয়',
            kind: EvidenceKind.notConnected,
          ),
        ],
        nextStepBn: 'বাজার পাতায় দাম দেখে সিদ্ধান্ত নিন।',
        actions: [
          AssistantAction(
            labelBn: 'বাজারদর দেখুন',
            destination: AssistantDestination.market,
          ),
        ],
      );
    }

    if (q.contains('জমি') || q.contains('মাঠ')) {
      return const AssistantAnswer(
        origin: AnswerOrigin.demo,
        directAnswerBn: 'আপনার জমির তথ্য "আমার জমি" পাতায় আছে।',
        reasonBn:
            'সহকারী এখনো আপনার জমির ডেটা পড়তে পারে না, তাই অবস্থা '
            'নিয়ে কোনো মূল্যায়ন দেওয়া হচ্ছে না।',
        evidence: [_demoEvidence, _liveMissing],
        nextStepBn: 'জমি খুলে সর্বশেষ তথ্য দেখুন।',
        actions: [
          AssistantAction(
            labelBn: 'আমার জমি',
            destination: AssistantDestination.fields,
          ),
        ],
      );
    }

    return const AssistantAnswer(
      origin: AnswerOrigin.notConnected,
      directAnswerBn: 'এই প্রশ্নের উত্তর এখন দিতে পারছি না।',
      reasonBn:
          'লাইভ AI সহকারী এখনো সংযুক্ত হয়নি। ডেমো মোডে শুধু নিচের '
          'প্রস্তাবিত প্রশ্নগুলোর নমুনা উত্তর আছে।',
      evidence: [_liveMissing],
    );
  }
}

/// The only voice input in this phase: reports that no speech
/// recognition is connected. Never simulates listening.
class UnavailableVoiceInput implements AssistantVoiceInput {
  const UnavailableVoiceInput();

  @override
  bool get isAvailable => false;

  @override
  Future<String?> listen() async => null;
}
