import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:agri_guardian/screens/diagnosis_result.dart';
import 'package:agri_guardian/shared/demo/showcase_story.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _bangla = RegExp('[ঀ-৿]');

Iterable<String> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('bn'),
  Size size = const Size(420, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const DiagnosisResultScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Bangla: Bangla headings, demo provenance and no English labels',
    (tester) async {
      await _pump(tester);

      expect(find.text('রোগ শনাক্তকরণ ফলাফল'), findsOneWidget);
      expect(find.text('ডেমো ফলাফল'), findsOneWidget);
      expect(find.text(DemoStory.diagnosis.nameBn), findsWidgets);
      expect(find.text('আজ কী করবেন? (জরুরি ৩টি পদক্ষেপ)'), findsOneWidget);
      expect(find.text('সম্পূর্ণ ব্যবস্থাপনা পরিকল্পনা দেখুন'), findsOneWidget);

      // Bangla numerals in Bangla mode.
      expect(find.text('AI নির্ভরতা ৯২%'), findsOneWidget);
      expect(find.text('৯২%'), findsWidgets);

      // No English UI copy leaks into Bangla mode (scientific name excepted).
      final english = _texts(tester).where(
        (t) =>
            t.isNotEmpty &&
            !_bangla.hasMatch(t) &&
            RegExp('[A-Za-z]').hasMatch(t) &&
            t != DemoStory.diagnosis.pathogen &&
            t != 'DEMO',
      );
      expect(
        english,
        isEmpty,
        reason: 'English leaked into Bangla UI: $english',
      );
    },
  );

  testWidgets('English: English headings, Bangla-free text, same numbers', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('en'));

    expect(find.text('Disease detection result'), findsOneWidget);
    expect(find.text('Demo result'), findsOneWidget);
    expect(find.text(DemoStory.diagnosis.nameEn), findsWidgets);
    expect(find.text('What to do today? (3 urgent steps)'), findsOneWidget);
    expect(find.text('View the full management plan'), findsOneWidget);

    // Values are unchanged; only the numerals follow the locale.
    expect(find.text('AI confidence 92%'), findsOneWidget);
    expect(find.text('92%'), findsWidgets);

    final bangla = _texts(tester).where(_bangla.hasMatch);
    expect(bangla, isEmpty, reason: 'Bangla leaked into English UI: $bangla');
  });

  testWidgets('scientific name and dosage text stay exactly as recorded', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('en'));

    expect(find.text(DemoStory.diagnosis.pathogen), findsOneWidget);
    expect(
      find.textContaining('0.75 g of tricyclazole 75 WP per litre of water'),
      findsOneWidget,
    );
    expect(find.textContaining('Magnaporthe oryzae'), findsWidgets);
  });

  testWidgets('save reports that saving is unavailable, never a fake save', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await tester.pump();

    expect(
      find.text('এখনো ফলাফল সংরক্ষণের সুবিধা চালু হয়নি।'),
      findsOneWidget,
    );
    expect(find.textContaining('সংরক্ষিত হয়েছে'), findsNothing);
  });

  testWidgets('share reports that sharing is unavailable (English)', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('en'));

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pump();

    expect(find.text('Sharing is not available yet.'), findsOneWidget);
  });

  testWidgets('small phone: no layout overflow in either language', (
    tester,
  ) async {
    for (final locale in const [Locale('bn'), Locale('en')]) {
      await _pump(tester, locale: locale, size: const Size(320, 640));
      expect(tester.takeException(), isNull, reason: locale.languageCode);
    }
  });
}
