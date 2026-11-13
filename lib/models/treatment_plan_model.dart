/// Model representing the 7-day Treatment & Management Roadmap
class TreatmentPlanModel {
  final String cropName;
  final String diseaseNameBn;
  final String diseaseNameEn;
  final String riskCategory;
  final double confidencePercentage;
  final List<TodayActionItem> todayActions;
  final List<PlanTimelineStage> stages;
  final List<String> scientificGuidelines;
  final String observationCountdown;
  final double progress;

  const TreatmentPlanModel({
    required this.cropName,
    required this.diseaseNameBn,
    required this.diseaseNameEn,
    required this.riskCategory,
    required this.confidencePercentage,
    required this.todayActions,
    required this.stages,
    required this.scientificGuidelines,
    required this.observationCountdown,
    required this.progress,
  });

  factory TreatmentPlanModel.sampleRiceBlastPlan() {
    return const TreatmentPlanModel(
      cropName: 'ধানের বোরো',
      diseaseNameBn: 'ধানের ব্লাস্ট',
      diseaseNameEn: 'Rice Blast',
      riskCategory: 'মাঝারি থেকে বেশি ঝুঁকি',
      confidencePercentage: 92.0,
      todayActions: [
        TodayActionItem(
          stepNumber: 1,
          title: 'অতিরিক্ত নাইট্রোজেন সার আপাতত বন্ধ রাখুন',
          subtitle: 'এখন নতুন করে ইউরিয়া/নাইট্রোজেন প্রয়োগ করবেন না।',
          iconType: 'chemical_stop',
        ),
        TodayActionItem(
          stepNumber: 2,
          title: 'আক্রান্ত পাতার পরিষ্কার কাছের ছবি তুলুন',
          subtitle: 'বিভিন্ন কোণ থেকে ২টি ছবি তুলুন, যেন দাগ স্পষ্ট দেখা যায়।',
          iconType: 'camera',
        ),
        TodayActionItem(
          stepNumber: 3,
          title: 'স্থানীয় কৃষি কর্মকর্তা/বিশেষজ্ঞের সাথে নিশ্চিত করুন',
          subtitle: 'ছবি ও তথ্য দেখিয়ে পরামর্শ নিন।',
          iconType: 'expert',
        ),
      ],
      stages: [
        PlanTimelineStage(
          stageKey: 'day0',
          title: 'দিন ০ (আজ)',
          statusText: 'সম্পন্ন',
          isCurrent: false,
          isCompleted: true,
          tasks: [
            'নাইট্রোজেন বন্ধ রাখুন',
            'জমি পর্যবেক্ষণ করুন',
            'ছবি তুলে সংরক্ষণ করুন',
          ],
        ),
        PlanTimelineStage(
          stageKey: 'day2_3',
          title: 'দিন ২–৩',
          statusText: 'চলমান',
          isCurrent: true,
          isCompleted: false,
          tasks: [
            'উপযুক্ত ছত্রাকনাশক প্রয়োগ করুন',
            'ক্ষেত নিয়মিত পর্যবেক্ষণ করুন',
            'প্রয়োজনে বিশেষজ্ঞের সাথে কথা বলুন',
          ],
        ),
        PlanTimelineStage(
          stageKey: 'day5_7',
          title: 'দিন ৫–৭',
          statusText: 'আগামীতে',
          isCurrent: false,
          isCompleted: false,
          tasks: [
            'পরিস্থিতির উন্নতি হয়েছে কি না মূল্যায়ন করুন',
            'প্রয়োজনে পুনরায় ছত্রাকনাশক প্রয়োগ করুন',
            'আবার ছবি তুলুন',
          ],
        ),
      ],
      scientificGuidelines: [
        'প্রতিরোধী জাত ব্যবহার ব্লাস্ট নিয়ন্ত্রণের সবচেয়ে গুরুত্বপূর্ণ উপায়।',
        'অতিরিক্ত নাইট্রোজেন প্রয়োগ ব্লাস্টের ঝুঁকি বাড়াতে পারে।',
        'নাইট্রোজেন ভারসাম্য রেখে ভাগে ভাগে প্রয়োগ করা উচিত।',
        'জমিতে সঠিক পানির ব্যবস্থাপনা (অতিখরা/অতিরিক্ত পানি এড়ানো) সহায়ক।',
        'প্রয়োজনে ও বিশেষজ্ঞ পরামর্শে ছত্রাকনাশক ব্যবহার করতে হবে।',
      ],
      observationCountdown: 'পরবর্তী পর্যবেক্ষণ: ৪৮ ঘণ্টা পরে',
      progress: 0.0,
    );
  }
}

class TodayActionItem {
  final int stepNumber;
  final String title;
  final String subtitle;
  final String iconType;

  const TodayActionItem({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.iconType,
  });
}

class PlanTimelineStage {
  final String stageKey;
  final String title;
  final String statusText;
  final bool isCurrent;
  final bool isCompleted;
  final List<String> tasks;

  const PlanTimelineStage({
    required this.stageKey,
    required this.title,
    required this.statusText,
    required this.isCurrent,
    required this.isCompleted,
    required this.tasks,
  });
}
