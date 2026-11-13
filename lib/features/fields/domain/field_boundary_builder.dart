import 'package:latlong2/latlong.dart' as latlng;

import '../../../shared/models/field.dart';

/// Pure helper for field boundary vertex collection and GeoJSON Polygon construction.
class FieldBoundaryBuilder {
  FieldBoundaryBuilder._();

  static const int minVertices = 3;
  static const double duplicateEpsilon = 1e-5; // ~1.1m coordinate tolerance

  /// Returns unique points by discarding duplicate points within 1e-5 tolerance.
  static List<latlng.LatLng> filterUniquePoints(List<latlng.LatLng> points) {
    final unique = <latlng.LatLng>[];
    for (final point in points) {
      final isDuplicate = unique.any(
        (existing) =>
            (existing.latitude - point.latitude).abs() < duplicateEpsilon &&
            (existing.longitude - point.longitude).abs() < duplicateEpsilon,
      );
      if (!isDuplicate) unique.add(point);
    }
    return unique;
  }

  /// Returns the count of distinct vertices.
  static int uniquePointCount(List<latlng.LatLng> points) =>
      filterUniquePoints(points).length;

  /// Returns true if at least 3 unique vertices are provided.
  static bool hasEnoughVertices(List<latlng.LatLng> points) =>
      uniquePointCount(points) >= minVertices;

  /// Formats points as a closed GeoJSON Polygon (longitude first, per RFC 7946).
  /// Returns null if fewer than 3 unique vertices are provided.
  static GeoJsonPolygon? buildGeoJson(List<latlng.LatLng> points) {
    final unique = filterUniquePoints(points);
    if (unique.length < minVertices) return null;

    final ring = [
      for (final point in unique) [point.longitude, point.latitude],
      [unique.first.longitude, unique.first.latitude],
    ];
    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }
}

