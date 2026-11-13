import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'network_exception.dart';

/// Supplies the bearer token for the current request, or null if signed
/// out. Supabase remains the *only* authentication mechanism - this client
/// never mints or stores its own tokens, it just forwards Supabase's.
typedef AccessTokenProvider = Future<String?> Function();

/// Thin JSON HTTP client for the FastAPI backend.
///
/// Every domain repository (fields, crop cycles) goes through this instead
/// of talking to Supabase or `dio` directly, so timeout handling, auth
/// headers, and error translation live in exactly one place.
class ApiClient {
  final Dio _dio;
  final AccessTokenProvider _accessTokenProvider;

  ApiClient({
    required AccessTokenProvider accessTokenProvider,
    Dio? dio,
    String? baseUrl,
  })  : _accessTokenProvider = accessTokenProvider,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                sendTimeout: ApiConfig.sendTimeout,
                contentType: 'application/json',
              ),
            );

  Future<Options> _authorizedOptions({String? idempotencyKey}) async {
    final token = await _accessTokenProvider();
    return Options(
      headers: {
        'Authorization': ?token == null ? null : 'Bearer $token',
        'Idempotency-Key': ?idempotencyKey,
      },
    );
  }

  /// Returns the decoded JSON body. FastAPI's list endpoints return a
  /// cursor envelope (`{items, next_cursor, has_more}`), so this is left as
  /// `dynamic` rather than forced into a `Map` - callers decode the shape
  /// they expect.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: await _authorizedOptions(),
      );
      return response.data;
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? data,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: await _authorizedOptions(idempotencyKey: idempotencyKey),
      );
      return response.data;
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        path,
        data: data,
        options: await _authorizedOptions(),
      );
      return response.data;
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: data,
        options: await _authorizedOptions(),
      );
      return response.data;
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  NetworkException _translate(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout();
      case DioExceptionType.connectionError:
        return NetworkException.noConnection();
      case DioExceptionType.badResponse:
        return _translateResponse(error);
      // badCertificate, cancel, unknown, and any future DioExceptionType
      // dio adds all fall back to a generic message rather than failing
      // to compile against a newer dio release.
      default:
        return NetworkException.unknown(error.message);
    }
  }

  /// Unpacks FastAPI's `{"error_code": ..., "detail": ...}` shape
  /// (`app/core/exceptions.py`) when present, otherwise falls back to a
  /// generic message for the status code.
  NetworkException _translateResponse(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final body = response?.data;

    String? detail;
    String? errorCode;
    if (body is Map<String, dynamic>) {
      detail = body['detail'] as String?;
      errorCode = body['error_code'] as String?;
    }

    if (statusCode == 401) {
      return NetworkException.unauthorized();
    }

    return NetworkException(
      detail ?? 'সার্ভার সমস্যা হয়েছে (স্ট্যাটাস: $statusCode)।',
      statusCode,
      errorCode,
    );
  }
}
