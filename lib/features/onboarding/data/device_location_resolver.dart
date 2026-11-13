import 'package:geolocator/geolocator.dart';

import '../../../core/services/permission_service.dart';
import '../domain/onboarding_profile.dart';

/// Why a device-location attempt did not produce coordinates.
enum LocationFailure { permissionDenied, serviceDisabled, unavailable }

class DeviceLocationResult {
  final double? latitude;
  final double? longitude;
  final LocationFailure? failure;

  const DeviceLocationResult.success(this.latitude, this.longitude)
    : failure = null;

  const DeviceLocationResult.failed(this.failure)
    : latitude = null,
      longitude = null;

  bool get isSuccess => failure == null;
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
        ),
      );
      return DeviceLocationResult.success(
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      return const DeviceLocationResult.failed(LocationFailure.unavailable);
    }
  }
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
