import 'package:flutter/material.dart';

import '../../../../screens/ai_analyzing.dart';

/// Compatibility entry point until a real inference endpoint is available.
/// It intentionally shows the unavailable state instead of a sample diagnosis.
class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) => const AiAnalyzingScreen();
}
