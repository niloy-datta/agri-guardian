/// The single showcase demo story shared by audience-facing screens that
/// have no real data source yet (Home's field card, Weather, AI Assistant,
/// Field Insights, Satellite Analysis, Diagnosis, Treatment Plan, Market,
/// Profile).
///
/// Everything here is sample content for demonstration - never a record
/// from the backend. Screens backed by real repositories (My Fields /
/// field details via `FieldRepository`, marketplace, offline sync) must
/// keep showing their server data and never read from this file.
///
/// Only identity and narrative context lives here (who, where, which
/// field, crop, issue, market). Per-screen figures such as NDVI, prices
/// or model confidence stay in their own screens unchanged.
library;

class DemoFarmer {
  final String nameEn;
  final String roleEn;
  final String roleBn;

  const DemoFarmer({
    required this.nameEn,
    required this.roleEn,
    required this.roleBn,
  });
}

class DemoLocation {
  final String upazilaBn;
  final String districtBn;
  final String districtEn;

  const DemoLocation({
    required this.upazilaBn,
    required this.districtBn,
    required this.districtEn,
  });
}

class DemoField {
  final String nameBn;
  final String nameEn;
  final double areaAcres;

  const DemoField({
    required this.nameBn,
    required this.nameEn,
    required this.areaAcres,
  });

  /// e.g. `২.৫ একর`
  String get areaBn => '${toBanglaDigits(_trim(areaAcres))} একর';

  /// e.g. `2.5 acres`
  String get areaEn => '${_trim(areaAcres)} acres';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class DemoCropCycle {
  final String cropBn;
  final String cropEn;

  /// Short variety label as shown in market listings, e.g. `ব্রি-২৮`.
  final String varietyShortBn;

  const DemoCropCycle({
    required this.cropBn,
    required this.cropEn,
    required this.varietyShortBn,
  });
}

/// Where in the field the showcase issues sit, so Field Insights and
/// Satellite Analysis point at the same zones.
class DemoFieldIssues {
  final String waterloggingZoneBn;
  final String waterloggingZoneEn;
  final String leafStressZoneBn;
  final String leafStressZoneEn;

  const DemoFieldIssues({
    required this.waterloggingZoneBn,
    required this.waterloggingZoneEn,
    required this.leafStressZoneBn,
    required this.leafStressZoneEn,
  });
}

/// The disease the showcase scan flow displays - labels only; the demo
/// confidence/severity stay where the diagnosis screens define them.
class DemoDiagnosis {
  final String nameBn;
  final String nameEn;
  final String pathogen;

  const DemoDiagnosis({
    required this.nameBn,
    required this.nameEn,
    required this.pathogen,
  });
}

/// "Now" conditions shared by Home's weather pills and the Weather Risk
/// Center's demo snapshot, so the two never disagree.
class DemoWeatherNow {
  final double temperatureC;
  final int humidityPercent;
  final String conditionBn;
  final String conditionEn;

  const DemoWeatherNow({
    required this.temperatureC,
    required this.humidityPercent,
    required this.conditionBn,
    required this.conditionEn,
  });
}

class DemoMarket {
  /// The farmer's nearest market - also the headline price source on the
  /// Market screen.
  final String homeMarketBn;

  const DemoMarket({required this.homeMarketBn});
}

abstract final class DemoStory {
  static const farmer = DemoFarmer(
    nameEn: 'Niloy',
    roleEn: 'AgriLume Farmer',
    roleBn: 'AgriLume কৃষক',
  );

  static const location = DemoLocation(
    upazilaBn: 'কিশোরগঞ্জ সদর',
    districtBn: 'কিশোরগঞ্জ',
    districtEn: 'Kishoreganj',
  );

  static const field = DemoField(
    nameBn: 'উত্তর জমি',
    nameEn: 'North Field',
    areaAcres: 2.5,
  );

  /// The number of fields in the showcase story (just [field]).
  static const fieldCount = 1;

  static const crop = DemoCropCycle(
    cropBn: 'বোরো ধান',
    cropEn: 'Boro Rice',
    varietyShortBn: 'ব্রি-২৮',
  );

  static const issues = DemoFieldIssues(
    waterloggingZoneBn: 'দক্ষিণ অংশে',
    waterloggingZoneEn: 'in the southern part',
    leafStressZoneBn: 'উত্তর-পশ্চিম অংশে',
    leafStressZoneEn: 'in the north-west part',
  );

  static const diagnosis = DemoDiagnosis(
    nameBn: 'ধানের ব্লাস্ট',
    nameEn: 'Rice Blast',
    pathogen: 'Magnaporthe oryzae',
  );

  static const weatherNow = DemoWeatherNow(
    temperatureC: 31,
    humidityPercent: 78,
    conditionBn: 'আংশিক মেঘলা',
    conditionEn: 'Partly Cloudy',
  );

  static const market = DemoMarket(homeMarketBn: 'কিশোরগঞ্জ সদর মোকাম');

  /// Label shown wherever a showcase value could be mistaken for live data.
  static const demoTagBn = 'ডেমো';
  static const demoTagEn = 'Demo';

  /// `উত্তর জমি · বোরো ধান`
  static String get fieldCropBn => '${field.nameBn} · ${crop.cropBn}';

  /// `North Field • Boro Rice`
  static String get fieldCropEn => '${field.nameEn} • ${crop.cropEn}';
}

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String toBanglaDigits(String s) => s.replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => _bnDigits[int.parse(m[0]!)],
);
