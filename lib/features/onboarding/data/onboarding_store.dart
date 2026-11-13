import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_profile.dart';

/// On-device persistence for the setup answers.
///
/// Deliberately local-only: these are the farmer's stated preferences, not
/// server records, so nothing here calls the API or Supabase. Field
/// business data still belongs to `FieldRepository`.
abstract interface class OnboardingStore {
  Future<OnboardingProfile> read();
  Future<void> write(OnboardingProfile profile);

  /// True once the farmer has finished setup at least once.
  Future<bool> isComplete();
  Future<void> markComplete();
  Future<void> clear();
}

class SharedPrefsOnboardingStore implements OnboardingStore {
  static const _kComplete = 'onboarding.complete';
  static const _kLanguage = 'onboarding.language';
  static const _kLocationMode = 'onboarding.location.mode';
  static const _kLocationLabel = 'onboarding.location.label';
  static const _kLocationLat = 'onboarding.location.lat';
  static const _kLocationLng = 'onboarding.location.lng';
  static const _kFarmerName = 'onboarding.farmer.name';
  static const _kFarmSize = 'onboarding.farm.sizeAcres';
  static const _kCurrentCrop = 'onboarding.farm.currentCrop';
  static const _kPreviousCrop = 'onboarding.field.previousCrop';
  static const _kSoilType = 'onboarding.field.soilType';
  static const _kBoundary = 'onboarding.field.boundaryGeoJson';
  static const _kBoundaryVertices = 'onboarding.field.boundaryVertices';
  static const _kGoal = 'onboarding.goal';

  final Future<SharedPreferences> _prefs;

  SharedPrefsOnboardingStore({Future<SharedPreferences>? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance();

  @override
  Future<OnboardingProfile> read() async {
    final p = await _prefs;

    final label = p.getString(_kLocationLabel);
    final location = label == null
        ? null
        : FarmLocation(
            mode: p.getString(_kLocationMode) == 'device'
                ? LocationMode.device
                : LocationMode.manual,
            label: label,
            latitude: p.getDouble(_kLocationLat),
            longitude: p.getDouble(_kLocationLng),
          );

    final boundaryJson = p.getString(_kBoundary);
    FieldBoundaryDraft? boundary;
    if (boundaryJson != null) {
      try {
        boundary = FieldBoundaryDraft(
          geoJson: jsonDecode(boundaryJson) as Map<String, dynamic>,
          vertexCount: p.getInt(_kBoundaryVertices) ?? 0,
        );
      } catch (_) {
        // A corrupt stored boundary is dropped rather than shown as if
        // the farmer had drawn it.
        boundary = null;
      }
    }

    return OnboardingProfile(
      language: p.containsKey(_kLanguage)
          ? AppLanguageCode.fromCode(p.getString(_kLanguage))
          : null,
      location: location,
      farmerName: p.getString(_kFarmerName),
      farmSizeAcres: p.getDouble(_kFarmSize),
      currentCrop: p.getString(_kCurrentCrop),
      fieldBoundary: boundary,
      previousCrop: p.getString(_kPreviousCrop),
      soilType: _soilFromName(p.getString(_kSoilType)),
      goal: _goalFromName(p.getString(_kGoal)),
    );
  }

  @override
  Future<void> write(OnboardingProfile profile) async {
    final p = await _prefs;

    await _setOrRemoveString(p, _kLanguage, profile.language?.code);

    final location = profile.location;
    await _setOrRemoveString(p, _kLocationLabel, location?.label);
    await _setOrRemoveString(p, _kLocationMode, location?.mode.name);
    await _setOrRemoveDouble(p, _kLocationLat, location?.latitude);
    await _setOrRemoveDouble(p, _kLocationLng, location?.longitude);

    await _setOrRemoveString(p, _kFarmerName, profile.farmerName);
    await _setOrRemoveDouble(p, _kFarmSize, profile.farmSizeAcres);
    await _setOrRemoveString(p, _kCurrentCrop, profile.currentCrop);

    final boundary = profile.fieldBoundary;
    await _setOrRemoveString(
      p,
      _kBoundary,
      boundary == null ? null : jsonEncode(boundary.geoJson),
    );
    if (boundary == null) {
      await p.remove(_kBoundaryVertices);
    } else {
      await p.setInt(_kBoundaryVertices, boundary.vertexCount);
    }

    await _setOrRemoveString(p, _kPreviousCrop, profile.previousCrop);
    await _setOrRemoveString(p, _kSoilType, profile.soilType?.name);
    await _setOrRemoveString(p, _kGoal, profile.goal?.name);
  }

  @override
  Future<bool> isComplete() async => (await _prefs).getBool(_kComplete) ?? false;

  @override
  Future<void> markComplete() async =>
      (await _prefs).setBool(_kComplete, true);

  @override
  Future<void> clear() async {
    final p = await _prefs;
    for (final key in const [
      _kComplete,
      _kLanguage,
      _kLocationMode,
      _kLocationLabel,
      _kLocationLat,
      _kLocationLng,
      _kFarmerName,
      _kFarmSize,
      _kCurrentCrop,
      _kPreviousCrop,
      _kSoilType,
      _kBoundary,
      _kBoundaryVertices,
      _kGoal,
    ]) {
      await p.remove(key);
    }
  }

  static Future<void> _setOrRemoveString(
    SharedPreferences p,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await p.remove(key);
    } else {
      await p.setString(key, value);
    }
  }

  static Future<void> _setOrRemoveDouble(
    SharedPreferences p,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await p.remove(key);
    } else {
      await p.setDouble(key, value);
    }
  }

  static SoilType? _soilFromName(String? name) {
    if (name == null) return null;
    for (final value in SoilType.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static FarmGoal? _goalFromName(String? name) {
    if (name == null) return null;
    for (final value in FarmGoal.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
