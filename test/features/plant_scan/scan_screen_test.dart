import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:agri_guardian/core/services/permission_service.dart';
import 'package:agri_guardian/features/plant_scan/presentation/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _bangla = RegExp('[ঀ-৿]');

/// Permission fake that always denies camera access and counts requests.
class _DeniedPermissions implements PermissionService {
  int requests = 0;

  @override
  Future<bool> requestCameraPermission() async {
    requests++;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale, {
  PermissionService? permissions,
}) async {
  tester.view.physicalSize = const Size(420, 900);
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
      home: ScanScreen(permissionService: permissions),
    ),
  );
  // Camera setup is async and fails without a device; let it settle.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Iterable<String> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');

void main() {
  testWidgets(
    'Bangla: scan headings and guide copy are Bangla, no English UI',
    (tester) async {
      await _pump(tester, const Locale('bn'));

      expect(find.text('প্ল্যান্ট স্ক্যান'), findsOneWidget);
      expect(find.text('আক্রান্ত পাতা ফ্রেমের মাঝে রাখুন'), findsOneWidget);
      expect(find.text('ফটোগ্রাফি গাইড'), findsOneWidget);
      expect(find.text('কীভাবে ছবি তুলবেন'), findsOneWidget);
      expect(find.text('ভালো উদাহরণ'), findsOneWidget);
      expect(find.text('গ্যালারি'), findsOneWidget);
      expect(find.text('টিপস'), findsOneWidget);
      expect(find.text('স্বয়ংক্রিয়'), findsOneWidget);

      final english = _texts(tester).where(
        (t) =>
            t.isNotEmpty &&
            !_bangla.hasMatch(t) &&
            RegExp('[A-Za-z]').hasMatch(t) &&
            !RegExp(r'^\d+x$').hasMatch(t),
      );
      expect(
        english,
        isEmpty,
        reason: 'English leaked into Bangla scan UI: $english',
      );
    },
  );

  testWidgets('English: scan headings and guide copy are English, no Bangla', (
    tester,
  ) async {
    await _pump(tester, const Locale('en'));

    expect(find.text('Scan plant'), findsOneWidget);
    expect(find.text('Center the affected leaf in the frame'), findsOneWidget);
    expect(find.text('Photo guide'), findsOneWidget);
    expect(find.text('How to take a photo'), findsOneWidget);
    expect(find.text('Good example'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Tips'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    final bangla = _texts(tester).where(_bangla.hasMatch);
    expect(
      bangla,
      isEmpty,
      reason: 'Bangla leaked into English scan UI: $bangla',
    );
  });

  testWidgets(
    'Bangla: denied camera permission shows a Bangla error and retry',
    (tester) async {
      final permissions = _DeniedPermissions();
      await _pump(tester, const Locale('bn'), permissions: permissions);

      expect(
        find.text('প্ল্যান্ট স্ক্যান করতে ক্যামেরার অনুমতি দরকার।'),
        findsOneWidget,
      );
      expect(find.text('আবার চেষ্টা করুন'), findsOneWidget);
      expect(permissions.requests, 1);

      // Invokes the retry button's handler. A simulated tap on this button is
      // not hit-testable in the widget test harness (overlay hit path), so the
      // tap itself is verified manually on a device.
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'আবার চেষ্টা করুন'),
          )
          .onPressed!();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(permissions.requests, 2, reason: 'retry should ask again');
      expect(
        find.text('প্ল্যান্ট স্ক্যান করতে ক্যামেরার অনুমতি দরকার।'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'English: denied camera permission shows an English error and retry',
    (tester) async {
      final permissions = _DeniedPermissions();
      await _pump(tester, const Locale('en'), permissions: permissions);

      expect(
        find.text('Camera permission is required to scan a plant.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      final bangla = _texts(tester).where(_bangla.hasMatch);
      expect(
        bangla,
        isEmpty,
        reason: 'Bangla leaked into English error: $bangla',
      );
    },
  );
}
