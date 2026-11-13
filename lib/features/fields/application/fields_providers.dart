import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../services/firebase_service.dart';
import '../../../shared/models/crop_cycle.dart';
import '../../../shared/models/field.dart';
import '../data/crop_cycle_repository.dart';
import '../data/field_repository.dart';
import '../data/offline/crop_cycle_cache_store.dart';
import '../data/offline/field_cache_store.dart';
import '../data/offline/offline_write_result.dart';
import '../data/offline/sync_queue_store.dart';
import 'field_sync_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final fieldCacheStoreProvider = Provider<FieldCacheStore>((ref) {
  return FieldCacheStore(ref.watch(appDatabaseProvider));
});

final cropCycleCacheStoreProvider = Provider<CropCycleCacheStore>((ref) {
  return CropCycleCacheStore(ref.watch(appDatabaseProvider));
});

final syncQueueStoreProvider = Provider<SyncQueueStore>((ref) {
  return SyncQueueStore(ref.watch(appDatabaseProvider));
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// The FastAPI client, authenticated with the current Supabase session's
/// access token on every request. Supabase remains authentication only -
/// no field or crop-cycle data is read from or written to it directly.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    accessTokenProvider: FirebaseService.instance.getAccessToken,
  );
});

final fieldRepositoryProvider = Provider<FieldRepository>((ref) {
  return FieldRepository(
    ref.watch(apiClientProvider),
    cacheStore: ref.watch(fieldCacheStoreProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final cropCycleRepositoryProvider = Provider<CropCycleRepository>((ref) {
  return CropCycleRepository(
    ref.watch(apiClientProvider),
    cacheStore: ref.watch(cropCycleCacheStoreProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final fieldSyncServiceProvider = Provider<FieldSyncService>((ref) {
  return FieldSyncService(
    fieldRepository: ref.watch(fieldRepositoryProvider),
    cropCycleRepository: ref.watch(cropCycleRepositoryProvider),
    syncQueueStore: ref.watch(syncQueueStoreProvider),
    fieldCacheStore: ref.watch(fieldCacheStoreProvider),
    cropCycleCacheStore: ref.watch(cropCycleCacheStoreProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});

final pendingMutationsProvider = StreamProvider<List<PendingMutation>>((ref) {
  return ref.watch(syncQueueStoreProvider).watchAllMutations();
});

/// Loads, creates, and updates the signed-in user's fields against
/// FastAPI with offline fallback and mutation queueing.
class FieldsController extends AsyncNotifier<List<Field>> {
  @override
  Future<List<Field>> build() {
    return ref.read(fieldRepositoryProvider).fetchFields();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(fieldRepositoryProvider).fetchFields(),
    );
  }

  /// Creates a field or queues it locally if offline/network error.
  Future<OfflineWriteResult<Field>> addOrQueueField({
    required String name,
    required GeoJsonPolygon boundary,
    required String countryCode,
    String? region,
    String? district,
    String? upazila,
    required String idempotencyKey,
  }) async {
    final connectivity = ref.read(connectivityServiceProvider);
    final isConnected = await connectivity.isConnected();

    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final payloadJson = jsonEncode({
      'name': name,
      'boundary': boundary,
      'country_code': countryCode,
      'region': region,
      'district': district,
      'upazila': upazila,
    });

    if (!isConnected) {
      await ref
          .read(syncQueueStoreProvider)
          .enqueue(
            type: 'field_create',
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            customMutationId: tempId,
          );
      return OfflineWriteResult.queued(
        tempId: tempId,
        message: 'অফলাইন সিঙ্ক কিউতে সংরক্ষিত হয়েছে (সিঙ্কের অপেক্ষায়)',
      );
    }

    try {
      final created = await ref
          .read(fieldRepositoryProvider)
          .createField(
            name: name,
            boundary: boundary,
            countryCode: countryCode,
            region: region,
            district: district,
            upazila: upazila,
            idempotencyKey: idempotencyKey,
          );

      final current = state.value ?? const [];
      state = AsyncData([created, ...current]);
      return OfflineWriteResult.synced(created);
    } on FieldRepositoryException catch (error) {
      if (error.isRetryableNetworkFailure) {
        await ref
            .read(syncQueueStoreProvider)
            .enqueue(
              type: 'field_create',
              payloadJson: payloadJson,
              idempotencyKey: idempotencyKey,
              customMutationId: tempId,
            );
        return OfflineWriteResult.queued(
          tempId: tempId,
          message: 'নেটওয়ার্ক ত্রুটি। সিঙ্ক কিউতে সংরক্ষিত হয়েছে',
        );
      }
      rethrow;
    }
  }

  /// Backward-compatible wrapper for existing calls.
  Future<Field> addField({
    required String name,
    required GeoJsonPolygon boundary,
    required String countryCode,
    String? region,
    String? district,
    String? upazila,
    required String idempotencyKey,
  }) async {
    final result = await addOrQueueField(
      name: name,
      boundary: boundary,
      countryCode: countryCode,
      region: region,
      district: district,
      upazila: upazila,
      idempotencyKey: idempotencyKey,
    );

    if (result.isSynced) {
      return result.data!;
    } else {
      throw FieldRepositoryException(
        result.message ?? 'অফলাইনে সিঙ্ক কিউতে রাখা হয়েছে',
        isRetryableNetworkFailure: true,
      );
    }
  }

  Future<void> updateField(Field field) async {
    final updated = await ref
        .read(fieldRepositoryProvider)
        .updateField(
          id: field.id,
          name: field.name,
          region: field.region,
          district: field.district,
          upazila: field.upazila,
          status: field.status,
          expectedVersion: field.version,
        );

    _replace(updated);
  }

  Future<void> archiveField(Field field) async {
    final updated = await ref
        .read(fieldRepositoryProvider)
        .archiveField(id: field.id, expectedVersion: field.version);

    _replace(updated);
  }

  void _replace(Field updated) {
    final current = state.value ?? const [];
    state = AsyncData([
      for (final existing in current)
        if (existing.id == updated.id) updated else existing,
    ]);
  }
}

final fieldsControllerProvider =
    AsyncNotifierProvider<FieldsController, List<Field>>(FieldsController.new);

/// Looks up a single field from the already-loaded list by id, for the
/// field details screen. Returns null while loading, on error, or if the
/// id is not found (e.g. a stale route after archiving).
final fieldByIdProvider = Provider.family<Field?, String>((ref, id) {
  final fields = ref.watch(fieldsControllerProvider).value;
  if (fields == null) return null;
  for (final field in fields) {
    if (field.id == id) return field;
  }
  return null;
});

/// Loads and creates crop cycles for one field.
class FieldCropCyclesController
    extends FamilyAsyncNotifier<List<CropCycle>, String> {
  @override
  Future<List<CropCycle>> build(String fieldId) {
    return ref.read(cropCycleRepositoryProvider).fetchCyclesForField(fieldId);
  }

  Future<void> refresh() async {
    final fieldId = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cropCycleRepositoryProvider).fetchCyclesForField(fieldId),
    );
  }

  Future<OfflineWriteResult<CropCycle>> addOrQueueCycle({
    required String cropCode,
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? currentStage,
    String? irrigationType,
    String status = CropCycleStatus.planned,
    required String idempotencyKey,
  }) async {
    final fieldId = arg;
    final connectivity = ref.read(connectivityServiceProvider);
    final isConnected = await connectivity.isConnected();

    final payloadJson = jsonEncode({
      'field_id': fieldId,
      'crop_code': cropCode,
      'variety': variety,
      'planting_date': plantingDate?.toIso8601String(),
      'expected_harvest_date': expectedHarvestDate?.toIso8601String(),
      'current_stage': currentStage,
      'irrigation_type': irrigationType,
      'status': status,
    });

    final tempId = 'temp_crop_${DateTime.now().microsecondsSinceEpoch}';

    if (!isConnected || fieldId.startsWith('temp_')) {
      await ref
          .read(syncQueueStoreProvider)
          .enqueue(
            type: 'crop_cycle_create',
            payloadJson: payloadJson,
            idempotencyKey: idempotencyKey,
            customMutationId: tempId,
            parentMutationId: fieldId.startsWith('temp_') ? fieldId : null,
          );
      return OfflineWriteResult.queued(
        tempId: tempId,
        message: 'ফসলের তথ্য সিঙ্ক কিউতে রাখা হয়েছে',
      );
    }

    try {
      final created = await ref
          .read(cropCycleRepositoryProvider)
          .createCycle(
            fieldId: fieldId,
            cropCode: cropCode,
            variety: variety,
            plantingDate: plantingDate,
            expectedHarvestDate: expectedHarvestDate,
            currentStage: currentStage,
            irrigationType: irrigationType,
            status: status,
            idempotencyKey: idempotencyKey,
          );

      final current = state.value ?? const [];
      state = AsyncData([created, ...current]);
      return OfflineWriteResult.synced(created);
    } on CropCycleRepositoryException catch (error) {
      if (error.isRetryableNetworkFailure) {
        await ref
            .read(syncQueueStoreProvider)
            .enqueue(
              type: 'crop_cycle_create',
              payloadJson: payloadJson,
              idempotencyKey: idempotencyKey,
              customMutationId: tempId,
            );
        return OfflineWriteResult.queued(
          tempId: tempId,
          message: 'নেটওয়ার্ক ত্রুটি। ফসলের তথ্য সিঙ্ক কিউতে রাখা হয়েছে',
        );
      }
      rethrow;
    }
  }

  /// Backward-compatible wrapper for existing calls.
  Future<CropCycle> addCycle({
    required String cropCode,
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? currentStage,
    String? irrigationType,
    String status = CropCycleStatus.planned,
    required String idempotencyKey,
  }) async {
    final result = await addOrQueueCycle(
      cropCode: cropCode,
      variety: variety,
      plantingDate: plantingDate,
      expectedHarvestDate: expectedHarvestDate,
      currentStage: currentStage,
      irrigationType: irrigationType,
      status: status,
      idempotencyKey: idempotencyKey,
    );

    if (result.isSynced) {
      return result.data!;
    } else {
      throw CropCycleRepositoryException(
        result.message ?? 'অফলাইনে সিঙ্ক কিউতে রাখা হয়েছে',
        isRetryableNetworkFailure: true,
      );
    }
  }
}

final fieldCropCyclesControllerProvider =
    AsyncNotifierProvider.family<
      FieldCropCyclesController,
      List<CropCycle>,
      String
    >(FieldCropCyclesController.new);

/// The field's most recent crop cycle by `created_at` (the repository
/// already returns newest-first, matching the backend's ordering), or null
/// if none exists yet or the list has not loaded.
final activeCropCycleProvider = Provider.family<CropCycle?, String>((
  ref,
  fieldId,
) {
  final cycles = ref.watch(fieldCropCyclesControllerProvider(fieldId)).value;
  if (cycles == null || cycles.isEmpty) return null;
  return cycles.first;
});
