import '../../features/onboarding/data/device_location_resolver.dart';

class LocationService {
  Future<Map<String, double>> getCurrentCoordinates() async {
    final result = await GeolocatorLocationResolver().resolve();
    if (!result.isSuccess) throw StateError('Device location unavailable');
    return {'lat': result.latitude!, 'lng': result.longitude!};
  }
}
