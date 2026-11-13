import 'package:agri_guardian/shared/models/field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Field Model Tests', () {
    final sampleJson = {
      'id': 'field_uuid_101',
      'farmer_id': 'farmer_uuid_202',
      'name': 'Green Paddy Field',
      'boundary': {
        'type': 'Polygon',
        'coordinates': [
          [
            [90.4125, 23.8103],
            [90.4130, 23.8105],
            [90.4135, 23.8100],
            [90.4125, 23.8103],
          ]
        ],
      },
      'centroid': {
        'longitude': 90.4130,
        'latitude': 23.8102,
      },
      'area_sq_m': 12345.67,
      'area_acres': 3.05,
      'country_code': 'BD',
      'region': 'Dhaka',
      'district': 'Gazipur',
      'upazila': 'Sreepur',
      'status': FieldStatus.active,
      'created_at': '2026-09-20T10:00:00Z',
      'updated_at': '2026-09-21T12:30:00Z',
      'version': 2,
    };

    test('Field.fromJson decodes complete FieldRead payload with numeric area_sq_m', () {
      final field = Field.fromJson(sampleJson);

      expect(field.id, equals('field_uuid_101'));
      expect(field.farmerId, equals('farmer_uuid_202'));
      expect(field.name, equals('Green Paddy Field'));
      expect(field.boundary['type'], equals('Polygon'));
      expect(field.centroid.longitude, equals(90.4130));
      expect(field.centroid.latitude, equals(23.8102));
      expect(field.areaSqM, equals(12345.67));
      expect(field.areaAcres, equals(3.05));
      expect(field.countryCode, equals('BD'));
      expect(field.region, equals('Dhaka'));
      expect(field.district, equals('Gazipur'));
      expect(field.upazila, equals('Sreepur'));
      expect(field.status, equals(FieldStatus.active));
      expect(field.version, equals(2));
    });

    test('Field.fromJson decodes string representation of Decimal area_sq_m and area_acres', () {
      final stringDecimalJson = Map<String, dynamic>.from(sampleJson)
        ..['area_sq_m'] = '12345.67'
        ..['area_acres'] = '3.05'
        ..['centroid'] = {
          'longitude': '90.4130',
          'latitude': '23.8102',
        };

      final field = Field.fromJson(stringDecimalJson);

      expect(field.areaSqM, equals(12345.67));
      expect(field.areaAcres, equals(3.05));
      expect(field.centroid.longitude, equals(90.4130));
      expect(field.centroid.latitude, equals(23.8102));
    });

    test('Field.fromJson throws FormatException on invalid non-numeric area_sq_m', () {
      final invalidJson = Map<String, dynamic>.from(sampleJson)
        ..['area_sq_m'] = 'invalid_number';

      expect(() => Field.fromJson(invalidJson), throwsA(isA<FormatException>()));
    });

    test('Field.toCreateJson formats request body per backend snake_case contract', () {
      final boundary = {
        'type': 'Polygon',
        'coordinates': [
          [
            [90.4125, 23.8103],
            [90.4130, 23.8105],
            [90.4135, 23.8100],
            [90.4125, 23.8103],
          ]
        ],
      };

      final createJson = Field.toCreateJson(
        name: 'New Field',
        boundary: boundary,
        countryCode: 'BD',
        region: 'Dhaka',
        district: 'Gazipur',
        upazila: 'Sreepur',
      );

      expect(createJson['name'], equals('New Field'));
      expect(createJson['boundary'], equals(boundary));
      expect(createJson['country_code'], equals('BD'));
      expect(createJson['region'], equals('Dhaka'));
      expect(createJson['district'], equals('Gazipur'));
      expect(createJson['upazila'], equals('Sreepur'));
    });

    test('Field.toUpdateJson includes expected_version and optional field updates', () {
      final updateJson = Field.toUpdateJson(
        name: 'Updated Field Name',
        status: FieldStatus.archived,
        expectedVersion: 3,
      );

      expect(updateJson['name'], equals('Updated Field Name'));
      expect(updateJson['status'], equals(FieldStatus.archived));
      expect(updateJson['expected_version'], equals(3));
    });
  });
}

