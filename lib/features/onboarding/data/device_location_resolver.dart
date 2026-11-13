import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/permission_service.dart';
import '../domain/onboarding_profile.dart';

/// Why a device-location attempt did not produce coordinates.
enum LocationFailure { permissionDenied, serviceDisabled, unavailable }

class DeviceLocationResult {
  final double? latitude;
  final double? longitude;
  final LocationFailure? failure;
  final String? placeName;
  final double? accuracyMeters;

  const DeviceLocationResult.success(
    this.latitude,
    this.longitude, {
    this.placeName,
    this.accuracyMeters,
  }) : failure = null;

  const DeviceLocationResult.failed(this.failure)
    : latitude = null,
      longitude = null,
      placeName = null,
      accuracyMeters = null;

  bool get isSuccess =>
      failure == null &&
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
}

/// Resolves the device's real coordinates, or reports honestly why it
/// could not. Never substitutes a guessed or hardcoded position - a
/// failure sends the farmer to the manual path instead.
abstract interface class DeviceLocationResolver {
  Future<DeviceLocationResult> resolve();
}

class GeolocatorLocationResolver implements DeviceLocationResolver {
  final PermissionService _permissions;

  GeolocatorLocationResolver({PermissionService? permissions})
    : _permissions = permissions ?? PermissionService();

  @override
  Future<DeviceLocationResult> resolve() async {
    try {
      if (!await _permissions.requestLocationPermission()) {
        return const DeviceLocationResult.failed(
          LocationFailure.permissionDenied,
        );
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationResult.failed(
          LocationFailure.serviceDisabled,
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      String? placeName;
      // Unsupported platforms retain the measured coordinates; geocoding
      // failure must never turn a valid fix into a guessed district.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        try {
          final places = await Geocoding()
              .placemarkFromCoordinates(position.latitude, position.longitude)
              .timeout(const Duration(seconds: 5));
          if (places.isNotEmpty) placeName = formatPlaceName(places.first);
        } catch (_) {
          // The device's geocoder may be offline or unavailable.
        }
      }
      return DeviceLocationResult.success(
        position.latitude,
        position.longitude,
        placeName: placeName,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return const DeviceLocationResult.failed(LocationFailure.unavailable);
    }
  }
}

/// Prefer the locality and administrative area, never a street or house number.
String? formatPlaceName(Placemark place) {
  final parts = <String>{};
  for (final group in [
    [place.locality, place.subLocality],
    [place.subAdministrativeArea, place.administrativeArea],
    [place.country],
  ]) {
    for (final value in group) {
      if (value != null && value.trim().isNotEmpty) {
        parts.add(value.trim());
        break;
      }
    }
  }
  return parts.isEmpty ? null : parts.join(', ');
}

/// Formats a fix for display without implying more precision than a
/// consumer GPS gives.
String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

/// Convenience for building the stored location from a confirmed label.
FarmLocation buildFarmLocation({
  required LocationMode mode,
  required String label,
  double? latitude,
  double? longitude,
}) {
  return FarmLocation(
    mode: mode,
    label: label.trim(),
    latitude: latitude,
    longitude: longitude,
  );
}
