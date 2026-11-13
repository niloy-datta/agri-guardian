import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_guardian/core/storage/app_database.dart';

/// Simulates a device still on schema v1 (pre-marketplace): only creates
/// the three original tables, at `schemaVersion = 1`. Used exclusively by
/// the migration test below to build a real v1 database file on disk,
/// which the real [AppDatabase] (schemaVersion 2) then opens and upgrades
/// - exercising the actual `AppDatabase.migration` code path, not a
/// reimplementation of it.
class _V1OnlyDatabase extends AppDatabase {
  _V1OnlyDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createTable(cachedFields);
      await migrator.createTable(cachedCropCycles);
      await migrator.createTable(pendingMutations);
    },
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Cache & Queue Tests', () {
    test('CachedFields table upserts and retrieves fields correctly', () async {
      await db
          .into(db.cachedFields)
          .insert(
            CachedFieldsCompanion.insert(
              serverId: 'f-101',
              payloadJson: '{"id":"f-101","name":"Test Field 1"}',
              serverVersion: 1,
              serverCreatedAt: DateTime.now(),
              serverUpdatedAt: DateTime.now(),
              cachedAt: DateTime.now(),
            ),
          );

      final fields = await db.select(db.cachedFields).get();
      expect(fields.length, equals(1));
      expect(fields.first.serverId, equals('f-101'));
    });

    test(
      'PendingMutations table handles order and status transitions',
      () async {
        await db
            .into(db.pendingMutations)
            .insert(
              PendingMutationsCompanion.insert(
                mutationId: 'mut-1',
                type: 'field_create',
                payloadJson: '{"name":"Field A"}',
                idempotencyKey: 'idemp-1',
                status: 'pending',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

        await db
            .into(db.pendingMutations)
            .insert(
              PendingMutationsCompanion.insert(
                mutationId: 'mut-2',
                type: 'crop_cycle_create',
                payloadJson: '{"crop_code":"RICE_BORO"}',
                idempotencyKey: 'idemp-2',
                status: 'pending',
                createdAt: DateTime.now().add(const Duration(seconds: 1)),
                updatedAt: DateTime.now().add(const Duration(seconds: 1)),
              ),
            );

        final pending =
            await (db.select(db.pendingMutations)
                  ..where((tbl) => tbl.status.equals('pending'))
                  ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
                .get();

        expect(pending.length, equals(2));
        expect(pending[0].mutationId, equals('mut-1'));
        expect(pending[1].mutationId, equals('mut-2'));

        // Mark first completed
        await (db.update(
          db.pendingMutations,
        )..where((tbl) => tbl.mutationId.equals('mut-1'))).write(
          const PendingMutationsCompanion(
            status: Value('completed'),
            resolvedServerId: Value('srv-field-101'),
          ),
        );

        final remaining = await (db.select(
          db.pendingMutations,
        )..where((tbl) => tbl.status.equals('pending'))).get();
        expect(remaining.length, equals(1));
        expect(remaining.first.mutationId, equals('mut-2'));
      },
    );
  });

  group('Schema v1 -> v2 migration', () {
    test(
      'existing data survives upgrade and the two new tables appear',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'app_database_migration_test',
        );
        final dbFile = File('${tempDir.path}/v1.sqlite');
        addTearDown(() async {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        });

        // Build a real v1 database file: only the three original tables.
        final v1Db = _V1OnlyDatabase(NativeDatabase(dbFile));
        await v1Db
            .into(v1Db.cachedFields)
            .insert(
              CachedFieldsCompanion.insert(
                serverId: 'f-v1-1',
                payloadJson: '{"id":"f-v1-1"}',
                serverVersion: 1,
                serverCreatedAt: DateTime.utc(2026, 1, 1),
                serverUpdatedAt: DateTime.utc(2026, 1, 1),
                cachedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v1Db
            .into(v1Db.cachedCropCycles)
            .insert(
              CachedCropCyclesCompanion.insert(
                serverId: 'cc-v1-1',
                fieldServerId: 'f-v1-1',
                payloadJson: '{"id":"cc-v1-1"}',
                serverVersion: 1,
                serverCreatedAt: DateTime.utc(2026, 1, 1),
                serverUpdatedAt: DateTime.utc(2026, 1, 1),
                cachedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v1Db
            .into(v1Db.pendingMutations)
            .insert(
              PendingMutationsCompanion.insert(
                mutationId: 'mut-v1-1',
                type: 'field_create',
                payloadJson: '{"name":"Pre-migration field"}',
                idempotencyKey: 'idemp-v1-1',
                status: 'pending',
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await v1Db.close();

        // Reopen the same file with the real, current AppDatabase
        // (schemaVersion 2) - drift detects the v1 -> v2 gap and runs the
        // real `AppDatabase.migration.onUpgrade`, not a test double of it.
        final upgradedDb = AppDatabase(NativeDatabase(dbFile));

        final fields = await upgradedDb.select(upgradedDb.cachedFields).get();
        expect(fields.length, equals(1));
        expect(fields.first.serverId, equals('f-v1-1'));

        final cycles = await upgradedDb
            .select(upgradedDb.cachedCropCycles)
            .get();
        expect(cycles.length, equals(1));
        expect(cycles.first.serverId, equals('cc-v1-1'));

        final mutations = await upgradedDb
            .select(upgradedDb.pendingMutations)
            .get();
        expect(mutations.length, equals(1));
        expect(mutations.first.mutationId, equals('mut-v1-1'));

        // The two new tables must exist and be usable after the upgrade.
        await upgradedDb
            .into(upgradedDb.cachedMarketplaceResponses)
            .insert(
              CachedMarketplaceResponsesCompanion.insert(
                cacheKey: 'browse:',
                scopeUserId: const Value(null),
                payloadJson: '{}',
                cachedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        final marketplaceRows = await upgradedDb
            .select(upgradedDb.cachedMarketplaceResponses)
            .get();
        expect(marketplaceRows.length, equals(1));

        await upgradedDb
            .into(upgradedDb.pendingCommerceOperations)
            .insert(
              PendingCommerceOperationsCompanion.insert(
                operationId: 'op-1',
                scopeUserId: 'user-1',
                operationType: 'CREATE_LISTING',
                payloadFingerprint: 'fp-1',
                idempotencyKey: 'idemp-op-1',
                payloadJson: '{}',
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        final commerceOps = await upgradedDb
            .select(upgradedDb.pendingCommerceOperations)
            .get();
        expect(commerceOps.length, equals(1));

        await upgradedDb.close();
      },
    );
  });
}
