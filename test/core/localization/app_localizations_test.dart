import 'package:agri_guardian/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _bangla = RegExp('[ঀ-৿]');

AppLocalizations _bn() => const AppLocalizations(Locale('bn'));
AppLocalizations _en() => const AppLocalizations(Locale('en'));

/// Every getter/method that renders text in a screen covered by the
/// localization work. Each entry must produce Bangla in `bn` and Bangla-free
/// text in `en`, so no English screen can show a Bangla string by accident.
final Map<String, String Function(AppLocalizations)> _screenKeys = {
  'myFieldsSyncQueue': (l) => l.myFieldsSyncQueue,
  'syncNow': (l) => l.syncNow,
  'loadingFields': (l) => l.loadingFields,
  'noFieldsYet': (l) => l.noFieldsYet,
  'firstFieldHint': (l) => l.firstFieldHint,
  'addFieldAction': (l) => l.addFieldAction,
  'boundaryLabel': (l) => l.boundaryLabel,
  'totalFieldsLabel': (l) => l.totalFieldsLabel,
  'totalAcresLabel': (l) => l.totalAcresLabel,
  'yourFieldsTitle': (l) => l.yourFieldsTitle,
  'satelliteNotRunYet': (l) => l.satelliteNotRunYet,
  'satelliteWaitingHint': (l) => l.satelliteWaitingHint,
  'newFieldFallback': (l) => l.newFieldFallback,
  'syncPendingStatus': (l) => l.syncPendingStatus,
  'conflictStatus': (l) => l.conflictStatus,
  'blockedStatus': (l) => l.blockedStatus,
  'savedLocallyNeedsSync': (l) => l.savedLocallyNeedsSync,
  'statusActive': (l) => l.statusActive,
  'statusInactive': (l) => l.statusInactive,
  'statusArchived': (l) => l.statusArchived,
  'fieldDetailsTitle': (l) => l.fieldDetailsTitle,
  'fieldNotFound': (l) => l.fieldNotFound,
  'areaServerLabel': (l) => l.areaServerLabel,
  'fieldStatusLabel': (l) => l.fieldStatusLabel,
  'cropCyclesTitle': (l) => l.cropCyclesTitle,
  'noCropCyclesYet': (l) => l.noCropCyclesYet,
  'cycleStatusPlanned': (l) => l.cycleStatusPlanned,
  'cycleStatusActive': (l) => l.cycleStatusActive,
  'cycleStatusHarvested': (l) => l.cycleStatusHarvested,
  'cycleStatusFailed': (l) => l.cycleStatusFailed,
  'cycleStatusCancelled': (l) => l.cycleStatusCancelled,
  'retry': (l) => l.retry,
  'weatherLoading': (l) => l.weatherLoading,
  'demoBannerTitle': (l) => l.demoBannerTitle,
  'offlineTitle': (l) => l.offlineTitle,
  'originDemo': (l) => l.originDemo,
  'decisionTitle': (l) => l.decisionTitle,
  'riskHigh': (l) => l.riskHigh,
  'addFieldTitle': (l) => l.addFieldTitle,
  'fieldNameRequired': (l) => l.fieldNameRequired,
  'countryCodeInvalid': (l) => l.countryCodeInvalid,
  'boundaryRequired': (l) => l.boundaryRequired,
  'boundaryPickerTitle': (l) => l.boundaryPickerTitle,
  'confirmBoundary': (l) => l.confirmBoundary,
  'closeAction': (l) => l.closeAction,
  'addLaterAction': (l) => l.addLaterAction,
  'doneLabel': (l) => l.doneLabel,
  'satMyFieldTwin': (l) => l.satMyFieldTwin,
  'satNdviHealth': (l) => l.satNdviHealth,
  'satSoilMoisture': (l) => l.satSoilMoisture,
  'satRiskLevel': (l) => l.satRiskLevel,
  'satLowHealthZone': (l) => l.satLowHealthZone,
  'satLegendWeak': (l) => l.satLegendWeak,
  'satLegendHealthy': (l) => l.satLegendHealthy,
  'satDemoNoLivePass': (l) => l.satDemoNoLivePass,
  'satAlertsTitle': (l) => l.satAlertsTitle,
  'satWaterloggingTitle': (l) => l.satWaterloggingTitle,
  'satSpotScan': (l) => l.satSpotScan,
  'satScanNow': (l) => l.satScanNow,
  'insFieldInsightsTitle': (l) => l.insFieldInsightsTitle,
  'insHealthyTitle': (l) => l.insHealthyTitle,
  'insPestRisk': (l) => l.insPestRisk,
  'insCropHealthTrend': (l) => l.insCropHealthTrend,
  'insAiInsight': (l) => l.insAiInsight,
  'insMostImportant': (l) => l.insMostImportant,
  'insWhyAlert': (l) => l.insWhyAlert,
  'insRecentRainfall': (l) => l.insRecentRainfall,
  'insDetected': (l) => l.insDetected,
  'insLowElevation': (l) => l.insLowElevation,
  'insOpenSatellite': (l) => l.insOpenSatellite,
  'voiceNotInstalled': (l) => l.voiceNotInstalled,
  'scanCameraPermissionNeeded': (l) => l.scanCameraPermissionNeeded,
  'scanCameraStartFailed': (l) => l.scanCameraStartFailed,
  'scanFlashUnsupported': (l) => l.scanFlashUnsupported,
  'scanZoomUnavailable': (l) => l.scanZoomUnavailable,
  'scanCameraNotReady': (l) => l.scanCameraNotReady,
  'scanCaptureFailed': (l) => l.scanCaptureFailed,
  'scanCameraUnavailable': (l) => l.scanCameraUnavailable,
  'scanTitle': (l) => l.scanTitle,
  'scanCenterLeaf': (l) => l.scanCenterLeaf,
  'flashAuto': (l) => l.flashAuto,
  'flashOff': (l) => l.flashOff,
  'scanKeepFocus': (l) => l.scanKeepFocus,
  'photoGuideTitle': (l) => l.photoGuideTitle,
  'howToTakePhoto': (l) => l.howToTakePhoto,
  'exampleGood': (l) => l.exampleGood,
  'exampleGoodDesc': (l) => l.exampleGoodDesc,
  'exampleTooFar': (l) => l.exampleTooFar,
  'exampleTooFarDesc': (l) => l.exampleTooFarDesc,
  'exampleBlurry': (l) => l.exampleBlurry,
  'exampleBlurryDesc': (l) => l.exampleBlurryDesc,
  'exampleObstructed': (l) => l.exampleObstructed,
  'exampleObstructedDesc': (l) => l.exampleObstructedDesc,
  'galleryLabel': (l) => l.galleryLabel,
  'galleryUnavailable': (l) => l.galleryUnavailable,
  'tipsLabel': (l) => l.tipsLabel,
  'photographyGuidelines': (l) => l.photographyGuidelines,
  'guideTip1': (l) => l.guideTip1,
  'guideTip2': (l) => l.guideTip2,
  'guideTip3': (l) => l.guideTip3,
  'guideTip4': (l) => l.guideTip4,
  'gotIt': (l) => l.gotIt,
  'account': (l) => l.account,
  'authTitleLogin': (l) => l.authTitleLogin,
  'authTitleRegister': (l) => l.authTitleRegister,
  'authHeadingLogin': (l) => l.authHeadingLogin,
  'authHeadingRegister': (l) => l.authHeadingRegister,
  'authSubtitle': (l) => l.authSubtitle,
  'authEmailLabel': (l) => l.authEmailLabel,
  'authCodeLabel': (l) => l.authCodeLabel,
  'authSendCode': (l) => l.authSendCode,
  'authVerifyAndContinue': (l) => l.authVerifyAndContinue,
  'authPleaseWait': (l) => l.authPleaseWait,
  'authSwitchToLogin': (l) => l.authSwitchToLogin,
  'authSwitchToRegister': (l) => l.authSwitchToRegister,
  'authRequestAnotherCode': (l) => l.authRequestAnotherCode,
  'authFirebaseNotConfigured': (l) => l.authFirebaseNotConfigured,
  'authEnterEmailError': (l) => l.authEnterEmailError,
  'authInvalidEmailError': (l) => l.authInvalidEmailError,
  'authEnterCodeError': (l) => l.authEnterCodeError,
  'authFailedError': (l) => l.authFailedError,
  'authNetworkError': (l) => l.authNetworkError,
  'authCodeSentNotice': (l) => l.authCodeSentNotice,
  'authDemoModeAction': (l) => l.authDemoModeAction,
  'authDemoModeNote': (l) => l.authDemoModeNote,
};

void main() {
  group('screen catalog keys', () {
    _screenKeys.forEach((name, read) {
      test('$name: Bangla in bn, no Bangla leakage in en', () {
        final bn = read(_bn());
        final en = read(_en());
        expect(bn.trim(), isNotEmpty, reason: '$name bn is empty');
        expect(en.trim(), isNotEmpty, reason: '$name en is empty');
        expect(_bangla.hasMatch(bn), isTrue, reason: '$name bn is not Bangla: $bn');
        expect(_bangla.hasMatch(en), isFalse, reason: '$name en leaks Bangla: $en');
      });
    });
  });

  group('locale-aware formatting', () {
    test('digits use Bangla numerals only in bn', () {
      expect(_bn().digits(12), '১২');
      expect(_en().digits(12), '12');
    });

    test('acresText and fieldsSummary follow the active locale', () {
      expect(_bn().acresText('2.5'), '২.৫ একর');
      expect(_en().acresText('2.5'), '2.5 acres');
      expect(_en().fieldsSummary(1, '2.5'), '1 field • 2.5 acres');
      expect(_bn().fieldsSummary(3, '2.5'), '৩টি জমি • ২.৫ একর');
    });

    test('chart dates and demo field lines follow the locale', () {
      expect(_bn().insChartDay(12), '১২ সেপ্টে');
      expect(_en().insChartDay(12), 'Sep 12');
      expect(_en().satFieldLine('North Field', 'Boro Rice', '2.5 acres'),
          'North Field • Boro Rice (2.5 acres)');
    });

    test('zoom message keeps the number in both locales', () {
      expect(_bn().scanZoomUnsupported(2), '২× জুম এই ক্যামেরায় সমর্থিত নয়।');
      expect(_en().scanZoomUnsupported(2), '2× zoom is not supported by this camera.');
    });

    test('pluralisation of pending changes in English', () {
      expect(_en().pendingSyncSummary(1), '1 change waiting to sync');
      expect(_en().pendingSyncSummary(2), '2 changes waiting to sync');
    });
  });
}
