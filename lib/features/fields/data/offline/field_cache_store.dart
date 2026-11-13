import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../shared/models/field.dart';

/// Manages local SQLite storage for server-confirmed [Field] snapshots.
class FieldCacheStore {
  final AppDatabase _db;

  const FieldCacheStore(this._db);

  /// Reads all cached server-confirmed fields, ordered newest created_at first.
  Future<List<Field>> getAllFields() async {
    final rows = await (_db.select(_db.cachedFields)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.serverCreatedAt,
                  mode: OrderingMode.desc,
                )
          ]))
        .get();

    return rows
        .map((row) => Field.fromJson(
              Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
            ))
        .toList(growable: false);
  }

  /// Atomically replaces the entire cached field list with fresh server results.
  Future<void> replaceAllFields(List<Field> fields) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.delete(_db.cachedFields).go();
      for (final field in fields) {
        await _db.into(_db.cachedFields).insertOnConflictUpdate(
              CachedFieldsCompanion(
                serverId: Value(field.id),
                payloadJson: Value(jsonEncode(toFullJson(field))),
                serverVersion: Value(field.version),
                serverCreatedAt: Value(field.createdAt),
                serverUpdatedAt: Value(field.updatedAt),
                cachedAt: Value(now),
              ),
            );
      }
    });
  }

  /// Upserts a single server-confirmed field snapshot.
  Future<void> upsertField(Field field) async {
    final now = DateTime.now();
    await _db.into(_db.cachedFields).insertOnConflictUpdate(
          CachedFieldsCompanion(
            serverId: Value(field.id),
            payloadJson: Value(jsonEncode(toFullJson(field))),
            serverVersion: Value(field.version),
            serverCreatedAt: Value(field.createdAt),
            serverUpdatedAt: Value(field.updatedAt),
            cachedAt: Value(now),
          ),
        );
  }

  /// Helper to convert a [Field] back to complete `FieldRead` map.
  static Map<String, dynamic> toFullJson(Field field) {
    return {
      'id': field.id,
      'farmer_id': field.farmerId,
      'name': field.name,
      'boundary': field.boundary,
      'centroid': {
        'longitude': field.centroid.longitude,
        'latitude': field.centroid.latitude,
      },
      'area_sq_m': field.areaSqM,
      'area_acres': field.areaAcres,
      'country_code': field.countryCode,
      'region': field.region,
      'district': field.district,
      'upazila': field.upazila,
      'status': field.status,
      'created_at': field.createdAt.toIso8601String(),
      'updated_at': field.updatedAt.toIso8601String(),
      'version': field.version,
    };
  }
}
