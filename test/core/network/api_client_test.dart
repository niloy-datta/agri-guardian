import 'dart:convert';
import 'dart:typed_data';

import 'package:agri_guardian/core/network/api_client.dart';
import 'package:agri_guardian/core/network/network_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  ResponseBody Function(RequestOptions options)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    if (handler != null) {
      return handler!(options);
    }
    return ResponseBody.fromString(
      jsonEncode({'status': 'ok'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ApiClient Tests', () {
    late _TestHttpClientAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _TestHttpClientAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = adapter;
    });

    test('GET sends Authorization: Bearer <token> when token provider returns a token',
        () async {
      final client = ApiClient(
        accessTokenProvider: () async => 'valid_bearer_token_123',
        dio: dio,
      );

      final result = await client.get('/test-endpoint');

      expect(result, equals({'status': 'ok'}));
      expect(adapter.lastOptions, isNotNull);
      expect(
        adapter.lastOptions!.headers['Authorization'],
        equals('Bearer valid_bearer_token_123'),
      );
    });

    test('POST sends Idempotency-Key when supplied', () async {
      final client = ApiClient(
        accessTokenProvider: () async => 'token_456',
        dio: dio,
      );

      await client.post(
        '/fields',
        data: {'name': 'Test Field'},
        idempotencyKey: 'idemp_key_789',
      );

      expect(adapter.lastOptions, isNotNull);
      expect(
        adapter.lastOptions!.headers['Idempotency-Key'],
        equals('idemp_key_789'),
      );
    });

    test('401 response translates into NetworkException with unauthorized status code 401',
        () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({'detail': 'Unauthorized access'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final client = ApiClient(
        accessTokenProvider: () async => null,
        dio: dio,
      );

      expect(
        () => client.get('/protected'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(401),
          ),
        ),
      );
    });

    test('Backend error response preserves status code, error code, and detail',
        () async {
      adapter.handler = (options) {
        return ResponseBody.fromString(
          jsonEncode({
            'error_code': 'field_version_conflict',
            'detail': 'The field version does not match.',
          }),
          409,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      };

      final client = ApiClient(
        accessTokenProvider: () async => 'token',
        dio: dio,
      );

      try {
        await client.patch('/fields/123');
        fail('Should have thrown NetworkException');
      } on NetworkException catch (e) {
        expect(e.statusCode, equals(409));
        expect(e.errorCode, equals('field_version_conflict'));
        expect(e.message, equals('The field version does not match.'));
      }
    });

    test('Connection timeout translates to timeout NetworkException', () async {
      adapter.handler = (options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      };

      final client = ApiClient(
        accessTokenProvider: () async => 'token',
        dio: dio,
      );

      expect(
        () => client.get('/timeout'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('সাড়া দিতে দেরি করছে'),
          ),
        ),
      );
    });
  });
}

