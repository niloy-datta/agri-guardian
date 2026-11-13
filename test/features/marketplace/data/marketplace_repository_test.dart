import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_guardian/core/network/api_client.dart';
import 'package:agri_guardian/core/network/network_exception.dart';
import 'package:agri_guardian/core/storage/app_database.dart';
import 'package:agri_guardian/features/marketplace/data/marketplace_cache_store.dart';
import 'package:agri_guardian/features/marketplace/data/marketplace_repository.dart';

class _MockApiClient implements ApiClient {
  Map<String, dynamic>? nextGetResponse;
  NetworkException? nextGetError;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (nextGetError != null) throw nextGetError!;
    return nextGetResponse;
  }

  @override
  Future<dynamic> post(
    String path, {
    dynamic data,
    String? idempotencyKey,
  }) async {
    throw UnimplementedError('not used by these tests');
  }

  @override
  Future<dynamic> patch(String path, {dynamic data}) async {
    throw UnimplementedError('not used by these tests');
  }
}

Map<String, dynamic> _emptyListingPage() => {
  'items': <dynamic>[],
  'next_cursor': null,
  'has_more': false,
};

/// Focused regression coverage for Task 8/18 (12B.0): a retryable network
/// failure (no HTTP status - timeout/unreachable) may fall back to the
/// local cache; a definitive server answer (401/404/409/422) never does,
/// so a stale cached page can never be mistaken for the server's actual
/// current answer.
void main() {
  late AppDatabase db;
  late MarketplaceCacheStore cacheStore;
  late _MockApiClient apiClient;
  late MarketplaceRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cacheStore = MarketplaceCacheStore(db);
    apiClient = _MockApiClient();
    repository = MarketplaceRepository(
      apiClient,
      cacheStore: cacheStore,
      scopeUserIdProvider: () => 'user-A',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('MarketplaceRepository cache fallback policy', () {
    test(
      'a retryable (no-status) network failure falls back to a cached page',
      () async {
        // Prime the cache with a real successful response first.
        apiClient.nextGetResponse = _emptyListingPage();
        await repository.fetchMyListings();

        // Now the same request fails with a connection/timeout error (no
        // HTTP status at all).
        apiClient.nextGetError = const NetworkException(
          'Connection timed out',
          null,
          null,
        );

        final page = await repository.fetchMyListings();
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      },
    );

    test(
      'a 401 never falls back to cache - it must reach the caller as-is',
      () async {
        apiClient.nextGetResponse = _emptyListingPage();
        await repository.fetchMyListings();

        apiClient.nextGetError = const NetworkException(
          'Unauthorized',
          401,
          'UNAUTHORIZED',
        );

        expect(
          () => repository.fetchMyListings(),
          throwsA(
            isA<MarketplaceRepositoryException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      },
    );

    test('a 409 conflict never falls back to cache - the UI must see the real '
        'conflict, never a stale success', () async {
      apiClient.nextGetResponse = _emptyListingPage();
      await repository.fetchOrders();

      apiClient.nextGetError = const NetworkException(
        'Conflict',
        409,
        'CONFLICT',
      );

      expect(
        () => repository.fetchOrders(),
        throwsA(
          isA<MarketplaceRepositoryException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.isConflict, 'isConflict', isTrue),
        ),
      );
    });

    test('a definitive 404 never falls back to cache', () async {
      apiClient.nextGetError = const NetworkException(
        'Not found',
        404,
        'NOT_FOUND',
      );

      expect(
        () => repository.fetchListing('missing-id'),
        throwsA(
          isA<MarketplaceRepositoryException>().having(
            (e) => e.isRetryableNetworkFailure,
            'isRetryableNetworkFailure',
            isFalse,
          ),
        ),
      );
    });
  });
}
