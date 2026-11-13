import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import 'idempotency.dart';

/// One of the three idempotency-protected commerce mutations (Task 16/17).
enum CommerceOperationType { createListing, placeBid, acceptBid }

extension on CommerceOperationType {
  String get wireName => switch (this) {
        CommerceOperationType.createListing => 'CREATE_LISTING',
        CommerceOperationType.placeBid => 'PLACE_BID',
        CommerceOperationType.acceptBid => 'ACCEPT_BID',
      };
}

/// Durable store for [PendingCommerceOperations] (Task 17/18/19).
///
/// The lifecycle: [begin] persists the operation and its idempotency key
/// *before* the HTTP request is sent. [complete] removes it on a
/// definitive outcome (success or a definitive 4xx the caller has
/// decided not to retry). On an ambiguous timeout/connection failure, the
/// caller does nothing - the row simply stays, and a later
/// [findExisting] call for the same logical request returns the same key
/// instead of minting a new one.
class CommerceOperationStore {
  const CommerceOperationStore(this._db);

  final AppDatabase _db;

  Future<String> begin({
    required String scopeUserId,
    required CommerceOperationType type,
    String? resourceId,
    required Map<String, dynamic> payload,
  }) async {
    final fingerprint = fingerprintPayload(payload);
    final existing = await findExisting(
      scopeUserId: scopeUserId,
      type: type,
      payload: payload,
    );
    if (existing != null) {
      return existing.idempotencyKey;
    }

    final key = generateIdempotencyKey();
    final now = DateTime.now().toUtc();
    await _db.into(_db.pendingCommerceOperations).insert(
          PendingCommerceOperationsCompanion.insert(
            operationId: key,
            scopeUserId: scopeUserId,
            operationType: type.wireName,
            resourceId: Value(resourceId),
            payloadFingerprint: fingerprint,
            idempotencyKey: key,
            payloadJson: jsonEncode(payload),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return key;
  }

  Future<PendingCommerceOperation?> findExisting({
    required String scopeUserId,
    required CommerceOperationType type,
    required Map<String, dynamic> payload,
  }) async {
    final fingerprint = fingerprintPayload(payload);
    return (_db.select(_db.pendingCommerceOperations)
          ..where(
            (t) =>
                t.scopeUserId.equals(scopeUserId) &
                t.operationType.equals(type.wireName) &
                t.payloadFingerprint.equals(fingerprint),
          ))
        .getSingleOrNull();
  }

  /// Definitive outcome reached (success or a resolved 4xx) - the pending
  /// record no longer represents an in-flight ambiguous operation.
  Future<void> complete(String idempotencyKey) async {
    await (_db.delete(_db.pendingCommerceOperations)
          ..where((t) => t.idempotencyKey.equals(idempotencyKey)))
        .go();
  }
}
