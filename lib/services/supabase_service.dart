import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access layer used alongside the existing Firebase fallback.
class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();
  static bool _initialized = false;

  static bool get isConfigured => _initialized;

  /// Initializes Supabase from build-time values supplied with --dart-define.
  ///
  /// An empty configuration is intentionally treated as a valid offline
  /// fallback state so Firebase can continue to initialize and the app can
  /// still run without secrets committed to source control.
  static Future<bool> initialize({
    required String url,
    required String publishableKey,
  }) async {
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      debugPrint(
        'Supabase init skipped: SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY were not provided.',
      );
      return false;
    }

    if (_initialized) return true;

    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      _initialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Supabase init notice: $error\n$stackTrace');
      return false;
    }
  }

  SupabaseClient? get client => _initialized ? Supabase.instance.client : null;

  User? get currentUser => client?.auth.currentUser;

  Session? get currentSession => client?.auth.currentSession;

  /// Returns the current session's access token, signing in anonymously if no
  /// valid session exists yet. Returns null if Supabase is unconfigured or auth fails.
  Future<String?> getOrCreateAccessToken() async {
    final supabase = client;
    if (supabase == null) return null;

    final existingToken = currentSession?.accessToken;
    if (existingToken != null && existingToken.isNotEmpty) {
      return existingToken;
    }

    final user = await signInAnonymously();
    if (user == null) return null;

    final newToken = currentSession?.accessToken;
    if (newToken != null && newToken.isNotEmpty) {
      return newToken;
    }

    return null;
  }

  /// Creates the anonymous Supabase user required for per-user scan RLS.
  ///
  /// Anonymous Sign-Ins must be enabled in the Supabase Dashboard. If it is
  /// disabled, this returns null and the caller can use the Firebase fallback.
  Future<User?> signInAnonymously() async {
    final supabase = client;
    if (supabase == null) return null;

    final existingUser = supabase.auth.currentUser;
    if (existingUser != null) return existingUser;

    try {
      final response = await supabase.auth.signInAnonymously();
      return response.user;
    } catch (error, stackTrace) {
      debugPrint('Supabase anonymous auth notice: $error\n$stackTrace');
      return null;
    }
  }

  /// Inserts a diagnosis result into public.scans.
  ///
  /// Returns false when Supabase is not configured, anonymous auth is not
  /// enabled, or the table/RLS configuration is unavailable.
  Future<bool> saveDiagnosisResult({
    required String diseaseName,
    required String confidence,
    required String severity,
    String? fieldName,
  }) async {
    final supabase = client;
    if (supabase == null) return false;

    final user = supabase.auth.currentUser ?? await signInAnonymously();
    if (user == null) return false;

    try {
      await supabase.from('scans').insert({
        'user_id': user.id,
        'disease': diseaseName,
        'confidence': confidence,
        'severity': severity,
        'field_name': fieldName,
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Supabase scan insert notice: $error\n$stackTrace');
      return false;
    }
  }

  /// Retrieves the signed-in user's scans ordered newest first.
  Future<List<Map<String, dynamic>>> getScans({int limit = 50}) async {
    final supabase = client;
    if (supabase == null) return const [];

    final user = supabase.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await supabase
          .from('scans')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Supabase scan retrieval notice: $error\n$stackTrace');
      return const [];
    }
  }
}
