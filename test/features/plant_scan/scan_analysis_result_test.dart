import 'package:agri_guardian/features/plant_scan/domain/scan_analysis_result.dart';
import 'package:agri_guardian/features/plant_scan/presentation/screens/scan_result_screen.dart';
import 'package:agri_guardian/screens/ai_analyzing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanAnalysisResult.unavailable', () {
    test('does not contain a fabricated diagnosis or confidence', () {
      final checkedAt = DateTime.utc(2026, 11, 10, 12);
      final result = ScanAnalysisResult.unavailable(checkedAt: checkedAt);

      expect(result.status, IntelligenceDataStatus.unavailable);
      expect(result.diseaseName, isNull);
      expect(result.confidence, isNull);
      expect(result.source, isNotEmpty);
      expect(result.checkedAt, checkedAt);
      expect(result.limitation, contains('No diagnosis was produced or saved'));
    });
  });

  testWidgets('scan flow shows the honest unavailable state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AiAnalyzingScreen(imagePath: '/tmp/capture.jpg')),
    );

    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(
      find.textContaining('No diagnosis was produced or saved.'),
      findsOneWidget,
    );
    expect(find.textContaining('ধানের ব্লাস্ট'), findsNothing);
    expect(find.textContaining('92%'), findsNothing);
  });

  testWidgets('scan result entry point does not show a sample diagnosis', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ScanResultScreen()));

    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.textContaining('ধানের ব্লাস্ট'), findsNothing);
    expect(find.textContaining('92%'), findsNothing);
  });
}
