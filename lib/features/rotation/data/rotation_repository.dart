import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_exception.dart';
import '../domain/rotation_models.dart';

/// Why a rotation request failed, so the UI can show the right state.
enum RotationFailureKind { offline, notFound, outsideBangladesh, unauthorized, server }

class RotationRepositoryException implements Exception {
  final RotationFailureKind kind;
  final String message;

  const RotationRepositoryException(this.kind, this.message);

  @override
  String toString() => message;
}

/// FastAPI-backed access to rotation profiles and scenario comparisons.
///
/// All provider calls (NASA, FAO, ISRIC, BAMIS) happen on the backend; this
/// class only talks to AgriGuardian's own authenticated API.
class RotationRepository {
  const RotationRepository(this._client);

  final ApiClient _client;

  Future<RotationProfile?> fetchProfile(String fieldId) async {
    try {
      final json = await _client.get(ApiEndpoints.fieldRotationProfile(fieldId));
      return RotationProfile.fromJson(Map<String, dynamic>.from(json as Map));
    } on NetworkException catch (e) {
      if (e.statusCode == 404) return null;
      throw _map(e);
    }
  }

  Future<RotationProfile> saveProfile(String fieldId, RotationProfile profile) async {
    try {
      final json = await _client.put(
        ApiEndpoints.fieldRotationProfile(fieldId),
        data: profile.toJson(),
      );
      return RotationProfile.fromJson(Map<String, dynamic>.from(json as Map));
    } on NetworkException catch (e) {
      throw _map(e);
    }
  }

  Future<RotationComparison> compareForField(
    String fieldId, {
    int maxOverlapDays = 0,
    String irrigationAccess = 'none',
    List<String> preferredOutcomes = const ['water_saving'],
  }) async {
    try {
      final json = await _client.post(
        ApiEndpoints.fieldRotationScenarios(fieldId),
        data: {
          'max_overlap_days': maxOverlapDays,
          'irrigation_access': irrigationAccess,
          'preferred_outcomes': preferredOutcomes,
        },
      );
      return RotationComparison.fromJson(Map<String, dynamic>.from(json as Map));
    } on NetworkException catch (e) {
      throw _map(e);
    }
  }

  RotationRepositoryException _map(NetworkException e) {
    final kind = switch (e.statusCode) {
      null => RotationFailureKind.offline,
      401 => RotationFailureKind.unauthorized,
      404 => RotationFailureKind.notFound,
      422 => RotationFailureKind.outsideBangladesh,
      _ => RotationFailureKind.server,
    };
    return RotationRepositoryException(kind, e.message);
  }
}
