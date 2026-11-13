/// FastAPI backend connection settings.
///
/// Read at compile time via `--dart-define`, matching the pattern
/// `SupabaseService.initialize` already uses for `SUPABASE_URL` in
/// `lib/main.dart`. A build with no value supplied falls back to the local
/// docker-compose API (`http://localhost:8000`) rather than failing to
/// compile, so `flutter run` keeps working against a local backend without
/// any extra flags.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
