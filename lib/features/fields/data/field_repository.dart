import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/network_exception.dart';
import '../../../shared/models/field.dart';
import 'offline/field_cache_store.dart';

/// Thrown by [FieldRepository] for any failure a caller should surface to
/// the user.
class FieldRepositoryException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final bool isRetryableNetworkFailure;

  const FieldRepositoryException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.isRetryableNetworkFailure = false,
  });

  @override
  String toString() => message;
}

/// A single page of `GET /api/v1/fields`, mirroring the backend's cursor
/// envelope (`CursorPage` in `app/core/pagination.py`) so callers can keep
/// paging without the repository hiding whether more data exists.
class FieldsPage {
  final List<Field> items;
  final String? nextCursor;
  final bool hasMore;

  const FieldsPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory FieldsPage.fromJson(Map<String, dynamic> json) {
    return FieldsPage(
      items: (json['items'] as List)
          .map((item) => Field.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool,
    );
  }
}

/// FastAPI-backed CRUD access to the caller's fields. Field data (boundary,
/// derived area/centroid) now lives only in Postgres/PostGIS behind
/// `backend/api/app/modules/fields`; this repository never writes field
/// business data to Supabase directly - Supabase remains authentication
/// only (see `ApiClient`, which forwards its access token).
class FieldRepository {
  const FieldRepository(
    this._client, {
    FieldCacheStore? cacheStore,
    ConnectivityService? connectivityService,
  })  : _cacheStore = cacheStore,
        _connectivityService = connectivityService;

  final ApiClient _client;
  final FieldCacheStore? _cacheStore;
  final ConnectivityService? _connectivityService;

  FieldRepositoryException _wrap(NetworkException error) {
    final isRetryable = error.statusCode == null;
    return FieldRepositoryException(
      error.message,
      statusCode: error.statusCode,
      errorCode: error.errorCode,
      isRetryableNetworkFailure: isRetryable,
    );
  }

  /// Fetches every field across as many pages as the server reports, so
  /// the My Fields screen keeps its simple "one list" contract. If offline,
  /// returns cached fields if available.
  Future<List<Field>> fetchFields() async {
    if (_connectivityService != null &&
        !await _connectivityService.isConnected()) {
      if (_cacheStore != null) {
        return _cacheStore.getAllFields();
      }
    }

    try {
      final fields = <Field>[];
      String? cursor;
      while (true) {
        final response = await _client.get(
          ApiEndpoints.fields,
          queryParameters: cursor == null ? null : {'cursor': cursor},
        );
        final page = FieldsPage.fromJson(Map<String, dynamic>.from(response));
        fields.addAll(page.items);
        if (!page.hasMore || page.nextCursor == null) break;
        cursor = page.nextCursor;
      }

      if (_cacheStore != null) {
        await _cacheStore.replaceAllFields(fields);
      }
      return fields;
    } on NetworkException catch (error) {
      if (error.statusCode == null && _cacheStore != null) {
        final cached = await _cacheStore.getAllFields();
        if (cached.isNotEmpty) {
          return cached;
        }
      }
      throw _wrap(error);
    }
  }

  Future<Field> fetchField(String id) async {
    if (_connectivityService != null &&
        !await _connectivityService.isConnected()) {
      if (_cacheStore != null) {
        final fields = await _cacheStore.getAllFields();
        for (final f in fields) {
          if (f.id == id) return f;
        }
      }
    }

    try {
      final response = await _client.get(ApiEndpoints.field(id));
      final field = Field.fromJson(Map<String, dynamic>.from(response));
      if (_cacheStore != null) {
        await _cacheStore.upsertField(field);
      }
      return field;
    } on NetworkException catch (error) {
      if (error.statusCode == null && _cacheStore != null) {
        final fields = await _cacheStore.getAllFields();
        for (final f in fields) {
          if (f.id == id) return f;
        }
      }
      throw _wrap(error);
    }
  }

  /// Creates a field from an already-validated GeoJSON boundary polygon.
  Future<Field> createField({
    required String name,
    required GeoJsonPolygon boundary,
    required String countryCode,
    String? region,
    String? district,
    String? upazila,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.fields,
        data: Field.toCreateJson(
          name: name,
          boundary: boundary,
          countryCode: countryCode,
          region: region,
          district: district,
          upazila: upazila,
        ),
        idempotencyKey: idempotencyKey,
      );
      final field = Field.fromJson(Map<String, dynamic>.from(response));
      if (_cacheStore != null) {
        await _cacheStore.upsertField(field);
      }
      return field;
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  Future<Field> updateField({
    required String id,
    String? name,
    String? region,
    String? district,
    String? upazila,
    String? status,
    required int expectedVersion,
  }) async {
    try {
      final response = await _client.patch(
        ApiEndpoints.field(id),
        data: Field.toUpdateJson(
          name: name,
          region: region,
          district: district,
          upazila: upazila,
          status: status,
          expectedVersion: expectedVersion,
        ),
      );
      final field = Field.fromJson(Map<String, dynamic>.from(response));
      if (_cacheStore != null) {
        await _cacheStore.upsertField(field);
      }
      return field;
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  /// There is no `DELETE /fields/{id}` endpoint - fields are archived, not
  /// deleted, so their crop-cycle and (future) NASA history stays intact.
  Future<Field> archiveField({
    required String id,
    required int expectedVersion,
  }) {
    return updateField(
      id: id,
      status: FieldStatus.archived,
      expectedVersion: expectedVersion,
    );
  }
}
