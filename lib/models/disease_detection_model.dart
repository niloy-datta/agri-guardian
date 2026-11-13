/// Model representing disease detection diagnosis and explanation
class DiseaseDetectionModel {
  final String diseaseNameBn;
  final String diseaseNameEn;
  final String scientificName;
  final double confidencePercentage;
  final String riskLevel;
  final String riskDescription;
  final String cropType;
  final String imagePath;
  final List<DetectionReason> reasons;
  final List<ImmediateAction> immediateActions;
  final String sourceNote;

  const DiseaseDetectionModel({
    required this.diseaseNameBn,
    required this.diseaseNameEn,
    required this.scientificName,
    required this.confidencePercentage,
    required this.riskLevel,
    required this.riskDescription,
    required this.cropType,
    required this.imagePath,
    required this.reasons,
    required this.immediateActions,
    required this.sourceNote,
  });

  /// Sample mock data matching the reference screenshot
  factory DiseaseDetectionModel.sampleRiceBlast() {
    return const DiseaseDetectionModel(
      diseaseNameBn: 'ধানের ব্লাস্ট',
      diseaseNameEn: 'Rice Blast',
      scientificName: 'Magnaporthe oryzae',
      confidencePercentage: 92.0,
      riskLevel: 'মাঝারি থেকে বেশি',
      riskDescription: 'বর্তমান অবস্থায় দ্রুত নজরদারি ও ব্যবস্থাপনা প্রয়োজন।',
      cropType: 'ধান (বোরো)',
      imagePath: 'assets/sample_leaf.jpg',
      reasons: [
        DetectionReason(
          title: 'ক্ষতের আকার মিলেছে',
          description: 'লম্বাটে/ডায়মন্ড আকৃতির ক্ষত – ব্লাস্টের সাধারণ লক্ষণ।',
          iconName: 'leaf',
        ),
        DetectionReason(
          title: 'রঙের ধরন মিলেছে',
          description: 'মাঝখানে ধূসর/সাদা, চারপাশে গাঢ় বাদামী সীমানা।',
          iconName: 'palette',
        ),
        DetectionReason(
          title: 'ছবির মান ভালো',
          description: 'পরিষ্কার ছবি, AI বিশ্লেষণের জন্য উপযুক্ত।',
          iconName: 'photo',
        ),
      ],
      immediateActions: [
        ImmediateAction(
          stepNumber: 1,
          instruction: 'আক্রান্ত পাতার আরও ২-৩টি ছবি তুলুন (ভিন্ন কোণ থেকে)',
        ),
        ImmediateAction(
          stepNumber: 2,
          instruction: 'অতিরিক্ত নাইট্রোজেন সার এখন না দিন (ব্লাস্ট ঝুঁকি বাড়াতে পারে)',
        ),
        ImmediateAction(
          stepNumber: 3,
          instruction: 'নিকটস্থ কৃষি কর্মকর্তা/বিশেষজ্ঞের সাথে নিশ্চিত করুন',
        ),
        ImmediateAction(
          stepNumber: 4,
          instruction: 'প্রয়োজনে প্রতিরোধী জাত ও মাঠ ব্যবস্থাপনার পরামর্শ দেখুন',
        ),
      ],
      sourceNote: 'ছবি + ফসলের তথ্য + রোগ লক্ষণের মিল',
    );
  }
}

class DetectionReason {
  final String title;
  final String description;
  final String iconName;

  const DetectionReason({
    required this.title,
    required this.description,
    required this.iconName,
  });
}

class ImmediateAction {
  final int stepNumber;
  final String instruction;

  const ImmediateAction({
    required this.stepNumber,
    required this.instruction,
  });
}
