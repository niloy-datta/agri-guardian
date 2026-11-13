/// What the six setup screens collect before the farmer reaches the
/// dashboard.
///
/// Everything here is the farmer's own stated input, kept on the device.
/// Nothing in this file is measured, derived from a provider, or sent to
/// a backend - see `OnboardingStore`.
library;

enum AppLanguage { bangla, english }

enum LocationMode {
  /// Resolved from the device's GPS.
  device,

  /// Typed or picked by the farmer.
  manual,
}

enum SoilType { clay, loam, sandy, silt, unknown }

enum FarmGoal { saveWater, increaseYield, improveSoil, reduceClimateRisk, findNextCrop }

extension AppLanguageCode on AppLanguage {
  String get code => switch (this) {
    AppLanguage.bangla => 'bn',
    AppLanguage.english => 'en',
  };

  static AppLanguage fromCode(String? code) =>
      code == 'en' ? AppLanguage.english : AppLanguage.bangla;
}

class FarmLocation {
  final LocationMode mode;

  /// Free-text place the farmer confirmed, e.g. `কিশোরগঞ্জ সদর, কিশোরগঞ্জ`.
  final String label;

  /// Present only when [mode] is [LocationMode.device] and a fix was
  /// actually obtained - never a guessed coordinate.
  final double? latitude;
  final double? longitude;

  const FarmLocation({
    required this.mode,
    required this.label,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

/// A drawn field boundary, stored as the GeoJSON the real boundary picker
/// returns (`showFieldBoundaryPicker`). No area is derived from it here -
/// PostGIS remains the only authority on geometry.
class FieldBoundaryDraft {
  final Map<String, dynamic> geoJson;
  final int vertexCount;

  const FieldBoundaryDraft({required this.geoJson, required this.vertexCount});
}

class OnboardingProfile {
  final AppLanguage? language;
  final FarmLocation? location;

  final String? farmerName;

  /// As typed by the farmer, in the unit they chose (acres).
  final double? farmSizeAcres;
  final String? currentCrop;

  final FieldBoundaryDraft? fieldBoundary;
  final String? previousCrop;
  final SoilType? soilType;

  final FarmGoal? goal;

  const OnboardingProfile({
    this.language,
    this.location,
    this.farmerName,
    this.farmSizeAcres,
    this.currentCrop,
    this.fieldBoundary,
    this.previousCrop,
    this.soilType,
    this.goal,
  });

  OnboardingProfile copyWith({
    AppLanguage? language,
    FarmLocation? location,
    String? farmerName,
    double? farmSizeAcres,
    String? currentCrop,
    FieldBoundaryDraft? fieldBoundary,
    String? previousCrop,
    SoilType? soilType,
    FarmGoal? goal,
  }) {
    return OnboardingProfile(
      language: language ?? this.language,
      location: location ?? this.location,
      farmerName: farmerName ?? this.farmerName,
      farmSizeAcres: farmSizeAcres ?? this.farmSizeAcres,
      currentCrop: currentCrop ?? this.currentCrop,
      fieldBoundary: fieldBoundary ?? this.fieldBoundary,
      previousCrop: previousCrop ?? this.previousCrop,
      soilType: soilType ?? this.soilType,
      goal: goal ?? this.goal,
    );
  }

  /// The minimum needed to leave setup: a language, a location and the
  /// farm basics. Field boundary and soil type stay optional.
  bool get isComplete =>
      language != null &&
      location != null &&
      (farmerName?.trim().isNotEmpty ?? false) &&
      farmSizeAcres != null &&
      (currentCrop?.trim().isNotEmpty ?? false) &&
      goal != null;
}
