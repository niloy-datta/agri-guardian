import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';

/// Reads/writes `CachedMarketplaceResponses` (Task 18/20).
///
/// `scopeUserId == null` means the row is the PUBLIC browse cache -
/// readable regardless of who is signed in. Any other row is PRIVATE and
/// is only ever returned to the exact same `scopeUserId` it was written
/// for; a mismatched or absent scope on read is treated as a cache miss,
/// never as "return whatever is there" - that is what would let account
/// A's cached marketplace history leak to account B on a shared device.
class MarketplaceCacheStore {
  const MarketplaceCacheStore(this._db);

  final AppDatabase _db;

  static const String publicScope = 'PUBLIC';

  Future<void> put({
    required String cacheKey,
    required String? scopeUserId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.cachedMarketplaceResponses).insertOnConflictUpdate(
          CachedMarketplaceResponsesCompanion.insert(
            cacheKey: cacheKey,
            scopeUserId: Value(scopeUserId),
            payloadJson: jsonEncode(payload),
            cachedAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Returns the cached payload only if its stored scope matches
  /// `scopeUserId` exactly (both null - the public cache - counts as a
  /// match). Never falls back to a differently-scoped row.
  Future<Map<String, dynamic>?> get({
    required String cacheKey,
    required String? scopeUserId,
  }) async {
    final row = await (_db.select(_db.cachedMarketplaceResponses)
          ..where((t) => t.cacheKey.equals(cacheKey)))
        .getSingleOrNull();
    if (row == null) return null;
    if (row.scopeUserId != scopeUserId) return null;
    return Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map);
  }

  Future<void> clearAllForUser(String scopeUserId) async {
    await (_db.delete(_db.cachedMarketplaceResponses)
          ..where((t) => t.scopeUserId.equals(scopeUserId)))
        .go();
  }
}
