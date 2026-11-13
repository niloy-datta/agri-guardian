import 'package:flutter/material.dart';
import '../widgets/treatment_step_card.dart';

class TreatmentPlanScreen extends StatelessWidget {
  const TreatmentPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('৭ দিনের ব্যবস্থাপনা পরিকল্পনা')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TreatmentStepCard(step: 1, title: 'অতিরিক্ত নাইট্রোজেন সার বন্ধ রাখুন', description: 'এখন ইউরিয়া প্রয়োগ করবেন না।'),
          TreatmentStepCard(step: 2, title: 'আক্রান্ত পাতার ছবি তুলে রাখুন', description: '২টি পরিষ্কার ছবি তুলুন।'),
          TreatmentStepCard(step: 3, title: 'বিশেষজ্ঞের সাথে নিশ্চিত করুন', description: 'স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।'),
        ],
      ),
    );
  }
}
