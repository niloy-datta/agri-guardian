import 'package:agri_guardian/features/fields/domain/field_boundary_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('FieldBoundaryBuilder pure geometry tests', () {
    test('three unique vertices are accepted', () {
      const points = [
        LatLng(23.8103, 90.4125),
        LatLng(23.8105, 90.4130),
        LatLng(23.8100, 90.4135),
      ];

      expect(FieldBoundaryBuilder.hasEnoughVertices(points), isTrue);
      expect(FieldBoundaryBuilder.uniquePointCount(points), equals(3));

      final geoJson = FieldBoundaryBuilder.buildGeoJson(points);
      expect(geoJson, isNotNull);
      expect(geoJson!['type'], equals('Polygon'));
    });

    test('fewer than three unique vertices are rejected', () {
      const points = [
        LatLng(23.8103, 90.4125),
        LatLng(23.8105, 90.4130),
      ];

      expect(FieldBoundaryBuilder.hasEnoughVertices(points), isFalse);
      expect(FieldBoundaryBuilder.uniquePointCount(points), equals(2));
      expect(FieldBoundaryBuilder.buildGeoJson(points), isNull);
    });

    test('duplicate-nearby points do not count as unique', () {
      // Third point is within 1e-5 tolerance (0.000005 diff)
      const points = [
        LatLng(23.810300, 90.412500),
        LatLng(23.810500, 90.413000),
        LatLng(23.810304, 90.412503),
      ];

      expect(FieldBoundaryBuilder.hasEnoughVertices(points), isFalse);
      expect(FieldBoundaryBuilder.uniquePointCount(points), equals(2));
      expect(FieldBoundaryBuilder.buildGeoJson(points), isNull);
    });

    test('output ring is closed and uses longitude, latitude coordinate order', () {
      const p1 = LatLng(23.8103, 90.4125);
      const p2 = LatLng(23.8105, 90.4130);
      const p3 = LatLng(23.8100, 90.4135);

      final geoJson = FieldBoundaryBuilder.buildGeoJson(const [p1, p2, p3]);
      expect(geoJson, isNotNull);

      final coordinates = geoJson!['coordinates'] as List;
      expect(coordinates, hasLength(1));

      final ring = coordinates.first as List;
      // 3 vertices + 1 closed closing vertex = 4 points total
      expect(ring, hasLength(4));

      // Longitude first, latitude second
      expect(ring[0], equals([90.4125, 23.8103]));
      expect(ring[1], equals([90.4130, 23.8105]));
      expect(ring[2], equals([90.4135, 23.8100]));
      // Ring closed with first point
      expect(ring[3], equals([90.4125, 23.8103]));
    });
  });
}

