import 'package:drift/drift.dart';
import '../../../../core/storage/app_database.dart';

class MutationType {
  MutationType._();
  static const String fieldCreate = 'field_create';
  static const String cropCycleCreate = 'crop_cycle_create';
}

class MutationStatus {
  MutationStatus._();
  static const String pending = 'pending';
  static const String completed = 'completed';
  static const String conflict = 'conflict';
  static const String blocked = 'blocked';
}

/// Durable mobile outbox store for field and crop cycle creation requests.
class SyncQueueStore {
  final AppDatabase _db;

  const SyncQueueStore(this._db);

  /// Enqueues a new mutation to be synced.
  Future<String> enqueue({
    required String type,
    required String payloadJson,
    required String idempotencyKey,
    String? targetServerId,
    String? parentMutationId,
    String? customMutationId,
  }) async {
    final now = DateTime.now();
    final mutationId =
        customMutationId ?? 'mut-${now.microsecondsSinceEpoch}';

    await _db.into(_db.pendingMutations).insertOnConflictUpdate(
          PendingMutationsCompanion(
            mutationId: Value(mutationId),
            type: Value(type),
            payloadJson: Value(payloadJson),
            idempotencyKey: Value(idempotencyKey),
            targetServerId: Value(targetServerId),
            parentMutationId: Value(parentMutationId),
            status: Value(MutationStatus.pending),
            attemptCount: const Value(0),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return mutationId;
  }

  /// Gets pending mutations ordered oldest-first.
  Future<List<PendingMutation>> getPendingOrdered() async {
    return (_db.select(_db.pendingMutations)
          ..where((t) => t.status.equals(MutationStatus.pending))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.asc,
                )
          ]))
        .get();
  }

  /// Gets all stored mutations ordered oldest-first.
  Future<List<PendingMutation>> getAllMutations() async {
    return (_db.select(_db.pendingMutations)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.asc,
                )
          ]))
        .get();
  }

  /// Watches all stored mutations ordered oldest-first.
  Stream<List<PendingMutation>> watchAllMutations() {
    return (_db.select(_db.pendingMutations)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.asc,
                )
          ]))
        .watch();
  }

  /// Gets a single mutation by its ID.
  Future<PendingMutation?> getMutation(String mutationId) async {
    return (_db.select(_db.pendingMutations)
          ..where((t) => t.mutationId.equals(mutationId)))
        .getSingleOrNull();
  }

  /// Updates the resolved server ID for a completed or in-progress mutation.
  Future<void> storeResolvedServerId(
    String mutationId,
    String resolvedServerId,
  ) async {
    final now = DateTime.now();
    await (_db.update(_db.pendingMutations)
          ..where((t) => t.mutationId.equals(mutationId)))
        .write(
      PendingMutationsCompanion(
        resolvedServerId: Value(resolvedServerId),
        updatedAt: Value(now),
      ),
    );
  }

  /// Marks a mutation completed.
  Future<void> markCompleted(String mutationId) async {
    final now = DateTime.now();
    await (_db.update(_db.pendingMutations)
          ..where((t) => t.mutationId.equals(mutationId)))
        .write(
      PendingMutationsCompanion(
        status: const Value(MutationStatus.completed),
        updatedAt: Value(now),
      ),
    );
  }

  /// Marks a mutation conflict (e.g. 409).
  Future<void> markConflict(
    String mutationId, {
    String? errorCode,
    String? message,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.pendingMutations)
          ..where((t) => t.mutationId.equals(mutationId)))
        .write(
      PendingMutationsCompanion(
        status: const Value(MutationStatus.conflict),
        lastErrorCode: Value(errorCode),
        lastErrorMessage: Value(message),
        updatedAt: Value(now),
      ),
    );
  }

  /// Marks a mutation blocked (e.g. 401, 403, 422).
  Future<void> markBlocked(
    String mutationId, {
    String? errorCode,
    String? message,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.pendingMutations)
          ..where((t) => t.mutationId.equals(mutationId)))
        .write(
      PendingMutationsCompanion(
        status: const Value(MutationStatus.blocked),
        lastErrorCode: Value(errorCode),
        lastErrorMessage: Value(message),
        updatedAt: Value(now),
      ),
    );
  }

  /// Increments attempt count and stores last error message on network failure.
  Future<void> incrementAttempt(
    String mutationId, {
    String? errorCode,
    String? message,
  }) async {
    final now = DateTime.now();
    final existing = await getMutation(mutationId);
    if (existing == null) return;

    await (_db.update(_db.pendingMutations)
          ..where((t) => t.mutationId.equals(mutationId)))
        .write(
      PendingMutationsCompanion(
        attemptCount: Value(existing.attemptCount + 1),
        lastErrorCode: Value(errorCode),
        lastErrorMessage: Value(message),
        updatedAt: Value(now),
      ),
    );
  }

  /// Safely removes completed mutations that no dependent pending/conflict/blocked
  /// mutation relies upon for a parent ID.
  Future<void> purgeCompletedSafely() async {
    final allMutations = await getAllMutations();
    final parentIdsInUse = allMutations
        .where((m) => m.status != MutationStatus.completed)
        .map((m) => m.parentMutationId)
        .whereType<String>()
        .toSet();

    final completedToPurge = allMutations
        .where((m) =>
            m.status == MutationStatus.completed &&
            !parentIdsInUse.contains(m.mutationId))
        .map((m) => m.mutationId)
        .toList();

    if (completedToPurge.isNotEmpty) {
      await (_db.delete(_db.pendingMutations)
            ..where((t) => t.mutationId.isIn(completedToPurge)))
          .go();
    }
  }
}
