/// Idempotency-key generation and payload fingerprinting for marketplace
/// mutations (Task 16/17).
///
/// A key belongs to exactly one logical operation. When a request's
/// outcome is genuinely unknown (a timeout, not a definitive server
/// response), the SAME key must be reused on retry - a new key would let
/// the backend's `IdempotencyGuard` treat it as a brand-new request and
/// create a duplicate. `PendingCommerceOperations` (Drift) is what makes
/// that possible: the key is persisted before the request is sent, not
/// generated fresh each time.
library;

import 'dart:convert';
import 'dart:math';

final Random _secureRandom = Random.secure();

/// A fresh, unique idempotency key - v4-UUID-shaped so the backend's
/// `Idempotency-Key` header validation (which just checks length) never
/// notices this isn't a "real" UUID library's output.
String generateIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// A stable fingerprint of a request payload, so a stored pending
/// operation can be matched against a subsequent identical retry (same
/// logical request) versus a genuinely different one (which must get its
/// own key, never reuse a stale one). Recursively sorts map keys so field
/// order in the caller's map never changes the fingerprint.
String fingerprintPayload(Map<String, dynamic> payload) {
  return jsonEncode(_sortedCopy(payload));
}

dynamic _sortedCopy(dynamic value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final key in sortedKeys) key: _sortedCopy(value[key])};
  }
  if (value is List) {
    return value.map(_sortedCopy).toList(growable: false);
  }
  return value;
}
