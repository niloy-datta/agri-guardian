/// Thrown by [ApiClient] for any failure a caller should surface to the
/// user: no connection, a timeout, or a non-2xx response from FastAPI.
///
/// Kept as a single exception type (not one per Dio error kind) so
/// repositories and UI code only ever need to catch one thing.
class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  /// The backend's `error_code` from its JSON error body
  /// (`app/core/exceptions.py`), e.g. `field_version_conflict`. Null when
  /// the failure never reached a JSON response (offline, timeout).
  final String? errorCode;

  const NetworkException(this.message, [this.statusCode, this.errorCode]);

  factory NetworkException.noConnection() => const NetworkException(
        'ইন্টারনেট সংযোগ নেই। সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
      );

  factory NetworkException.timeout() => const NetworkException(
        'সার্ভার সাড়া দিতে দেরি করছে। আবার চেষ্টা করুন।',
      );

  factory NetworkException.unauthorized() => const NetworkException(
        'অধিবেশনের মেয়াদ শেষ হয়ে গেছে। আবার সাইন ইন করুন।',
        401,
      );

  factory NetworkException.unknown([String? detail]) => NetworkException(
        detail ?? 'একটি অজানা সমস্যা হয়েছে। আবার চেষ্টা করুন।',
      );

  @override
  String toString() => 'NetworkException: $message '
      '(status: $statusCode, code: $errorCode)';
}
