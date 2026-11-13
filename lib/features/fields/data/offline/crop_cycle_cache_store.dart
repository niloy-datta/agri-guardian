import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../shared/models/crop_cycle.dart';

/// Manages local SQLite storage for server-confirmed [CropCycle] snapshots.
class CropCycleCacheStore {
  final AppDatabase _db;

  const CropCycleCacheStore(this._db);

  /// Reads cached crop cycles for a specific field, newest created_at first.
  Future<List<CropCycle>> getCyclesForField(String fieldServerId) async {
    final rows = await (_db.select(_db.cachedCropCycles)
          ..where((t) => t.fieldServerId.equals(fieldServerId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.serverCreatedAt,
                  mode: OrderingMode.desc,
                )
          ]))
        .get();

    return rows
        .map((row) => CropCycle.fromJson(
              Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
            ))
        .toList(growable: false);
  }

  /// Atomically replaces cached crop cycles for one field.
  Future<void> replaceCyclesForField(
    String fieldServerId,
    List<CropCycle> cycles,
  ) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(_db.cachedCropCycles)
            ..where((t) => t.fieldServerId.equals(fieldServerId)))
          .go();

      for (final cycle in cycles) {
        await _db.into(_db.cachedCropCycles).insertOnConflictUpdate(
              CachedCropCyclesCompanion(
                serverId: Value(cycle.id),
                fieldServerId: Value(cycle.fieldId),
                payloadJson: Value(jsonEncode(toFullJson(cycle))),
                serverVersion: Value(cycle.version),
                serverCreatedAt: Value(cycle.createdAt),
                serverUpdatedAt: Value(cycle.updatedAt),
                cachedAt: Value(now),
              ),
            );
      }
    });
  }

  /// Upserts a single server-confirmed crop cycle snapshot.
  Future<void> upsertCycle(CropCycle cycle) async {
    final now = DateTime.now();
    await _db.into(_db.cachedCropCycles).insertOnConflictUpdate(
          CachedCropCyclesCompanion(
            serverId: Value(cycle.id),
            fieldServerId: Value(cycle.fieldId),
            payloadJson: Value(jsonEncode(toFullJson(cycle))),
            serverVersion: Value(cycle.version),
            serverCreatedAt: Value(cycle.createdAt),
            serverUpdatedAt: Value(cycle.updatedAt),
            cachedAt: Value(now),
          ),
        );
  }

  /// Helper to convert [CropCycle] back to complete `CropCycleRead` map.
  static Map<String, dynamic> toFullJson(CropCycle cycle) {
    return {
      'id': cycle.id,
      'field_id': cycle.fieldId,
      'crop_code': cycle.cropCode,
      'variety': cycle.variety,
      'planting_date': cycle.plantingDate?.toIso8601String(),
      'expected_harvest_date': cycle.expectedHarvestDate?.toIso8601String(),
      'actual_harvest_date': cycle.actualHarvestDate?.toIso8601String(),
      'current_stage': cycle.currentStage,
      'irrigation_type': cycle.irrigationType,
      'status': cycle.status,
      'created_at': cycle.createdAt.toIso8601String(),
      'updated_at': cycle.updatedAt.toIso8601String(),
      'version': cycle.version,
    };
  }
}
