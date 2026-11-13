import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Checks if camera permission is already granted.
  Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Checks current camera permission and requests it if not already granted.
  /// Returns `true` only when permission is actually granted.
  /// Returns `false` when denied, restricted, or permanently denied.
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Checks if location permission is already granted.
  Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }

  /// Checks current location permission and requests it if not already granted.
  /// Returns `true` only when permission is actually granted.
  /// Returns `false` when denied, restricted, or permanently denied.
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      return true;
    }
    final result = await Permission.location.request();
    return result.isGranted;
  }
}
