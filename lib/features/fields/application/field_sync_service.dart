import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../data/field_repository.dart';
import '../data/crop_cycle_repository.dart';
import '../data/offline/field_cache_store.dart';
import '../data/offline/crop_cycle_cache_store.dart';
import '../data/offline/sync_queue_store.dart';

/// Result of a single sync execution pass.
class SyncPassResult {
  final int syncedCount;
  final int conflictCount;
  final int blockedCount;
  final int pendingRemainingCount;

  const SyncPassResult({
    required this.syncedCount,
    required this.conflictCount,
    required this.blockedCount,
    required this.pendingRemainingCount,
  });
}

/// Orchestrates syncing pending durable mutations (fields and crop cycles)
/// to the FastAPI server with dependency resolution.
class FieldSyncService {
  FieldSyncService({
    required FieldRepository fieldRepository,
    required CropCycleRepository cropCycleRepository,
    required SyncQueueStore syncQueueStore,
    required FieldCacheStore fieldCacheStore,
    required CropCycleCacheStore cropCycleCacheStore,
    required ConnectivityService connectivityService,
  })  : _fieldRepository = fieldRepository,
        _cropCycleRepository = cropCycleRepository,
        _syncQueueStore = syncQueueStore,
        _fieldCacheStore = fieldCacheStore,
        _cropCycleCacheStore = cropCycleCacheStore,
        _connectivityService = connectivityService;

  final FieldRepository _fieldRepository;
  final CropCycleRepository _cropCycleRepository;
  final SyncQueueStore _syncQueueStore;
  final FieldCacheStore _fieldCacheStore;
  final CropCycleCacheStore _cropCycleCacheStore;
  final ConnectivityService _connectivityService;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Runs a single sync execution pass over all pending mutations in order.
  /// Guaranteed to be single-threaded via lock flag [_isSyncing].
  Future<SyncPassResult> syncPendingMutations() async {
    if (_isSyncing) {
      final all = await _syncQueueStore.getAllMutations();
      return SyncPassResult(
        syncedCount: 0,
        conflictCount: all.where((m) => m.status == 'conflict').length,
        blockedCount: all.where((m) => m.status == 'blocked').length,
        pendingRemainingCount: all.where((m) => m.status == 'pending').length,
      );
    }

    _isSyncing = true;
    int syncedCount = 0;

    try {
      if (!await _connectivityService.isConnected()) {
        final all = await _syncQueueStore.getAllMutations();
        return SyncPassResult(
          syncedCount: 0,
          conflictCount: all.where((m) => m.status == 'conflict').length,
          blockedCount: all.where((m) => m.status == 'blocked').length,
          pendingRemainingCount: all.where((m) => m.status == 'pending').length,
        );
      }

      final pendingMutations = await _syncQueueStore.getPendingOrdered();

      for (final mutation in pendingMutations) {
        if (mutation.type == 'field_create') {
          final success = await _processFieldCreate(mutation);
          if (success) {
            syncedCount++;
          } else {
            final current = await _syncQueueStore.getMutation(mutation.mutationId);
            if (current?.status == 'pending') {
              break;
            }
          }
        } else if (mutation.type == 'crop_cycle_create') {
          final success = await _processCropCycleCreate(mutation);
          if (success) {
            syncedCount++;
          } else {
            final current = await _syncQueueStore.getMutation(mutation.mutationId);
            if (current?.status == 'pending') {
              break;
            }
          }
        }
      }

      if (syncedCount > 0) {
        try {
          final fields = await _fieldRepository.fetchFields();
          for (final f in fields) {
            await _cropCycleRepository.fetchCyclesForField(f.id);
          }
        } catch (e) {
          debugPrint('Failed to refresh cache after sync pass: $e');
        }
      }

      final allMutations = await _syncQueueStore.getAllMutations();
      return SyncPassResult(
        syncedCount: syncedCount,
        conflictCount: allMutations.where((m) => m.status == 'conflict').length,
        blockedCount: allMutations.where((m) => m.status == 'blocked').length,
        pendingRemainingCount:
            allMutations.where((m) => m.status == 'pending').length,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processFieldCreate(PendingMutation mutation) async {
    try {
      final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
      final boundaryJson = payload['boundary'] as Map<String, dynamic>;
      final boundary = Map<String, dynamic>.from(boundaryJson);
      final name = payload['name'] as String;
      final countryCode = (payload['country_code'] ?? payload['countryCode']) as String;
      final region = payload['region'] as String?;
      final district = payload['district'] as String?;
      final upazila = payload['upazila'] as String?;

      final field = await _fieldRepository.createField(
        name: name,
        boundary: boundary,
        countryCode: countryCode,
        region: region,
        district: district,
        upazila: upazila,
        idempotencyKey: mutation.idempotencyKey,
      );

      await _syncQueueStore.markCompleted(mutation.mutationId);
      await _fieldCacheStore.upsertField(field);
      await _syncQueueStore.storeResolvedServerId(mutation.mutationId, field.id);
      return true;
    } on FieldRepositoryException catch (e) {
      if (e.statusCode == 409) {
        await _syncQueueStore.markConflict(
          mutation.mutationId,
          message: e.message.isNotEmpty ? e.message : '409 Conflict',
        );
      } else if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 422) {
        await _syncQueueStore.markBlocked(
          mutation.mutationId,
          message: 'HTTP ${e.statusCode}: ${e.message}',
        );
      } else {
        await _syncQueueStore.incrementAttempt(
          mutation.mutationId,
          message: e.message,
        );
      }
      return false;
    } catch (e) {
      await _syncQueueStore.markBlocked(
        mutation.mutationId,
        message: 'Unexpected: $e',
      );
      return false;
    }
  }

  Future<bool> _processCropCycleCreate(PendingMutation mutation) async {
    try {
      final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
      String fieldId = payload['field_id'] as String;

      final allMutations = await _syncQueueStore.getAllMutations();
      for (final m in allMutations) {
        if (m.mutationId == fieldId && m.resolvedServerId != null) {
          fieldId = m.resolvedServerId!;
          break;
        }
      }

      if (fieldId.startsWith('temp_') || fieldId.startsWith('mut-')) {
        final parentMutation = allMutations.cast<PendingMutation?>().firstWhere(
            (m) => m?.mutationId == fieldId,
            orElse: () => null);
        if (parentMutation != null) {
          if (parentMutation.status == 'blocked' || parentMutation.status == 'conflict') {
            await _syncQueueStore.markBlocked(
              mutation.mutationId,
              message: 'Parent field creation failed (${parentMutation.status})',
            );
            return false;
          }
        }
        return false;
      }

      final cropCode = payload['crop_code'] as String;
      final variety = payload['variety'] as String?;
      final plantingDate = payload['planting_date'] != null
          ? DateTime.parse(payload['planting_date'] as String)
          : null;
      final expectedHarvestDate = payload['expected_harvest_date'] != null
          ? DateTime.parse(payload['expected_harvest_date'] as String)
          : null;
      final currentStage = payload['current_stage'] as String?;
      final irrigationType = payload['irrigation_type'] as String?;
      final status = (payload['status'] as String?) ?? 'planned';

      final cycle = await _cropCycleRepository.createCycle(
        fieldId: fieldId,
        cropCode: cropCode,
        variety: variety,
        plantingDate: plantingDate,
        expectedHarvestDate: expectedHarvestDate,
        currentStage: currentStage,
        irrigationType: irrigationType,
        status: status,
        idempotencyKey: mutation.idempotencyKey,
      );

      await _syncQueueStore.markCompleted(mutation.mutationId);
      await _cropCycleCacheStore.upsertCycle(cycle);
      return true;
    } on CropCycleRepositoryException catch (e) {
      if (e.statusCode == 409) {
        await _syncQueueStore.markConflict(
          mutation.mutationId,
          message: e.message.isNotEmpty ? e.message : '409 Conflict',
        );
      } else if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 422) {
        await _syncQueueStore.markBlocked(
          mutation.mutationId,
          message: 'HTTP ${e.statusCode}: ${e.message}',
        );
      } else {
        await _syncQueueStore.incrementAttempt(
          mutation.mutationId,
          message: e.message,
        );
      }
      return false;
    } catch (e) {
      await _syncQueueStore.markBlocked(
        mutation.mutationId,
        message: 'Unexpected: $e',
      );
      return false;
    }
  }
}
