import 'package:agri_guardian/features/onboarding/data/device_location_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  test('invalid and missing coordinates are not a successful fix', () {
    expect(const DeviceLocationResult.success(null, null).isSuccess, isFalse);
    expect(const DeviceLocationResult.success(91, 90).isSuccess, isFalse);
    expect(
      const DeviceLocationResult.success(double.nan, 90).isSuccess,
      isFalse,
    );
  });
  test(
    'place names use the actual locality and deduplicate administrative names',
    () {
      expect(
        formatPlaceName(
          Placemark(
            locality: 'Dhaka',
            subAdministrativeArea: 'Dhaka',
            country: 'Bangladesh',
          ),
        ),
        'Dhaka, Bangladesh',
      );
      expect(formatPlaceName(Placemark()), isNull);
    },
  );
}
