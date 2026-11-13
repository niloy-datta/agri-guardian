import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CachedFields extends Table {
  TextColumn get serverId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get serverVersion => integer()();
  DateTimeColumn get serverCreatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {serverId};
}

class CachedCropCycles extends Table {
  TextColumn get serverId => text()();
  TextColumn get fieldServerId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get serverVersion => integer()();
  DateTimeColumn get serverCreatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {serverId};
}

class PendingMutations extends Table {
  TextColumn get mutationId => text()();
  TextColumn get type => text()();
  TextColumn get payloadJson => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get targetServerId => text().nullable()();
  TextColumn get parentMutationId => text().nullable()();
  TextColumn get resolvedServerId => text().nullable()();
  TextColumn get status => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mutationId};
}

/// Cached marketplace GET responses (Task 18/20/21). `scopeUserId` is
/// null for the public browse listing cache and the authenticated
/// Supabase user id for every private cache (my-listings, my-bids,
/// orders) - a private row with a null/mismatched scope is never read
/// back for a different user, so one device switching accounts cannot
/// leak account A's marketplace history to account B.
class CachedMarketplaceResponses extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get scopeUserId => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

/// Durable record of an in-flight, ambiguous-outcome commerce mutation
/// (Task 17) - create listing, place bid, or accept bid. Persisted
/// *before* the request is sent; removed on a definitive success or a
/// definitive 4xx. Kept on a network timeout/connection error, so a
/// user-initiated retry of the same logical request reuses
/// `idempotencyKey` instead of minting a new one (which the backend's
/// `IdempotencyGuard` would treat as an unrelated request and could
/// double-create the resource).
class PendingCommerceOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get scopeUserId => text()();
  TextColumn get operationType => text()();
  TextColumn get resourceId => text().nullable()();
  TextColumn get payloadFingerprint => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {operationId};

  @override
  List<Set<Column>> get uniqueKeys => [
    {scopeUserId, operationType, payloadFingerprint},
  ];
}

@DriftDatabase(
  tables: [
    CachedFields,
    CachedCropCycles,
    PendingMutations,
    CachedMarketplaceResponses,
    PendingCommerceOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
    : super(
        e ??
            driftDatabase(
              name: 'agri_guardian_app',
              // Required on Flutter Web (drift_flutter throws
              // ArgumentError otherwise): points at the sqlite3 WASM
              // module and drift's background worker, both committed
              // under web/ matching the pinned drift/sqlite3 package
              // versions in pubspec.lock. Ignored on native platforms.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      // v1 -> v2: adds the two marketplace tables only. CachedFields,
      // CachedCropCycles, and PendingMutations are never touched, so
      // existing offline field/crop-cycle data and any queued sync
      // mutations survive the upgrade untouched.
      if (from < 2) {
        await migrator.createTable(cachedMarketplaceResponses);
        await migrator.createTable(pendingCommerceOperations);
      }
    },
  );
}
