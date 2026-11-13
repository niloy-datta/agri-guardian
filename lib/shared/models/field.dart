/// A field's boundary as it comes from the backend: a GeoJSON Polygon in
/// EPSG:4326 (`backend/api/app/shared/geo.py`), longitude first. Kept as a
/// raw map rather than parsed into typed points here - nothing in the
/// Flutter app recomputes geometry, it only displays what PostGIS already
/// validated and derived.
typedef GeoJsonPolygon = Map<String, dynamic>;

double _parseDouble(dynamic value, String fieldName) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid numeric value for $fieldName: $value');
}

/// A field's derived centroid, matching backend `Centroid`
/// (`app/modules/fields/schemas.py`). Computed by PostGIS, never by the
/// client.
class FieldCentroid {
  final double longitude;
  final double latitude;

  const FieldCentroid({required this.longitude, required this.latitude});

  factory FieldCentroid.fromJson(Map<String, dynamic> json) {
    return FieldCentroid(
      longitude: _parseDouble(json['longitude'], 'longitude'),
      latitude: _parseDouble(json['latitude'], 'latitude'),
    );
  }
}

class FieldStatus {
  FieldStatus._();

  static const String active = 'ACTIVE';
  static const String inactive = 'INACTIVE';
  static const String archived = 'ARCHIVED';
}

/// Mirrors `FieldRead` in `backend/api/app/modules/fields/schemas.py`
/// field-for-field. Every value here (area, centroid, status) is what the
/// server actually stored - there is no client-side field left unaccounted
/// for and no placeholder standing in for data the backend hasn't produced
/// yet (health/risk/moisture do not exist here on purpose: NASA-derived
/// intelligence has not been built yet, see field_details_screen.dart).
class Field {
  final String id;
  final String farmerId;
  final String name;
  final GeoJsonPolygon boundary;
  final FieldCentroid centroid;
  final double areaSqM;
  final double areaAcres;
  final String countryCode;
  final String? region;
  final String? district;
  final String? upazila;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const Field({
    required this.id,
    required this.farmerId,
    required this.name,
    required this.boundary,
    required this.centroid,
    required this.areaSqM,
    required this.areaAcres,
    required this.countryCode,
    this.region,
    this.district,
    this.upazila,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory Field.fromJson(Map<String, dynamic> json) {
    return Field(
      id: json['id'] as String,
      farmerId: json['farmer_id'] as String,
      name: json['name'] as String,
      boundary: Map<String, dynamic>.from(json['boundary'] as Map),
      centroid: FieldCentroid.fromJson(
        Map<String, dynamic>.from(json['centroid'] as Map),
      ),
      areaSqM: _parseDouble(json['area_sq_m'], 'area_sq_m'),
      areaAcres: _parseDouble(json['area_acres'], 'area_acres'),
      countryCode: json['country_code'] as String,
      region: json['region'] as String?,
      district: json['district'] as String?,
      upazila: json['upazila'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }

  /// Body for `POST /api/v1/fields` (`FieldCreate` in `fields/schemas.py`).
  /// `boundary` must already be a valid GeoJSON Polygon - the server is the
  /// only authority on structural and topological validity.
  static Map<String, dynamic> toCreateJson({
    required String name,
    required GeoJsonPolygon boundary,
    required String countryCode,
    String? region,
    String? district,
    String? upazila,
  }) {
    return {
      'name': name,
      'boundary': boundary,
      'country_code': countryCode,
      'region': ?region,
      'district': ?district,
      'upazila': ?upazila,
    };
  }

  /// Body for `PATCH /api/v1/fields/{id}` (`FieldUpdate`). Only the
  /// attributes actually changing should be passed; `expected_version`
  /// carries the optimistic-concurrency check.
  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? region,
    String? district,
    String? upazila,
    String? status,
    required int expectedVersion,
  }) {
    return {
      'name': ?name,
      'region': ?region,
      'district': ?district,
      'upazila': ?upazila,
      'status': ?status,
      'expected_version': expectedVersion,
    };
  }
}
