import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/network_exception.dart';
import '../../../shared/models/crop_cycle.dart';
import 'offline/crop_cycle_cache_store.dart';

/// Thrown by [CropCycleRepository] for any failure a caller should surface
/// to the user.
class CropCycleRepositoryException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final bool isRetryableNetworkFailure;

  const CropCycleRepositoryException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.isRetryableNetworkFailure = false,
  });

  @override
  String toString() => message;
}

/// A single page of `GET /api/v1/fields/{fieldId}/crop-cycles`, mirroring
/// the backend's cursor envelope.
class CropCyclesPage {
  final List<CropCycle> items;
  final String? nextCursor;
  final bool hasMore;

  const CropCyclesPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory CropCyclesPage.fromJson(Map<String, dynamic> json) {
    return CropCyclesPage(
      items: (json['items'] as List)
          .map((item) => CropCycle.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool,
    );
  }
}

/// FastAPI-backed CRUD access to a field's crop cycles.
class CropCycleRepository {
  const CropCycleRepository(
    this._client, {
    CropCycleCacheStore? cacheStore,
    ConnectivityService? connectivityService,
  })  : _cacheStore = cacheStore,
        _connectivityService = connectivityService;

  final ApiClient _client;
  final CropCycleCacheStore? _cacheStore;
  final ConnectivityService? _connectivityService;

  CropCycleRepositoryException _wrap(NetworkException error) {
    final isRetryable = error.statusCode == null;
    return CropCycleRepositoryException(
      error.message,
      statusCode: error.statusCode,
      errorCode: error.errorCode,
      isRetryableNetworkFailure: isRetryable,
    );
  }

  /// Fetches every crop cycle for a field across as many pages as the
  /// server reports. If offline, returns cached crop cycles if available.
  Future<List<CropCycle>> fetchCyclesForField(String fieldId) async {
    if (_connectivityService != null &&
        !await _connectivityService.isConnected()) {
      if (_cacheStore != null) {
        return _cacheStore.getCyclesForField(fieldId);
      }
    }

    try {
      final cycles = <CropCycle>[];
      String? cursor;
      while (true) {
        final response = await _client.get(
          ApiEndpoints.fieldCropCycles(fieldId),
          queryParameters: cursor == null ? null : {'cursor': cursor},
        );
        final page =
            CropCyclesPage.fromJson(Map<String, dynamic>.from(response));
        cycles.addAll(page.items);
        if (!page.hasMore || page.nextCursor == null) break;
        cursor = page.nextCursor;
      }

      if (_cacheStore != null) {
        await _cacheStore.replaceCyclesForField(fieldId, cycles);
      }
      return cycles;
    } on NetworkException catch (error) {
      if (error.statusCode == null && _cacheStore != null) {
        final cached = await _cacheStore.getCyclesForField(fieldId);
        if (cached.isNotEmpty) {
          return cached;
        }
      }
      throw _wrap(error);
    }
  }

  Future<CropCycle> fetchCycle(String cycleId) async {
    try {
      final response = await _client.get(ApiEndpoints.cropCycle(cycleId));
      final cycle = CropCycle.fromJson(Map<String, dynamic>.from(response));
      if (_cacheStore != null) {
        await _cacheStore.upsertCycle(cycle);
      }
      return cycle;
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  /// `idempotencyKey` should be stable across retries of the same
  /// submission, same rationale as `FieldRepository.createField`.
  Future<CropCycle> createCycle({
    required String fieldId,
    required String cropCode,
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? currentStage,
    String? irrigationType,
    String status = CropCycleStatus.planned,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.fieldCropCycles(fieldId),
        data: CropCycle.toCreateJson(
          cropCode: cropCode,
          variety: variety,
          plantingDate: plantingDate,
          expectedHarvestDate: expectedHarvestDate,
          currentStage: currentStage,
          irrigationType: irrigationType,
          status: status,
        ),
        idempotencyKey: idempotencyKey,
      );
      final cycle = CropCycle.fromJson(Map<String, dynamic>.from(response));
      if (_cacheStore != null) {
        await _cacheStore.upsertCycle(cycle);
      }
      return cycle;
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  Future<CropCycle> updateCycle({
    required String cycleId,
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    DateTime? actualHarvestDate,
    String? currentStage,
    String? irrigationType,
    String? status,
    required int expectedVersion,
  }) async {
    try {
      final response = await _client.patch(
        ApiEndpoints.cropCycle(cycleId),
        data: CropCycle.toUpdateJson(
          variety: variety,
          plantingDate: plantingDate,
          expectedHarvestDate: expectedHarvestDate,
          actualHarvestDate: actualHarvestDate,
          currentStage: currentStage,
          irrigationType: irrigationType,
          status: status,
          expectedVersion: expectedVersion,
        ),
      );
      final cycle = CropCycle.fromJson(Map<String, dynamic>.from(response));
      if (_cacheStore != null) {
        await _cacheStore.upsertCycle(cycle);
      }
      return cycle;
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }
}
