import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/network_exception.dart';
import 'marketplace_cache_store.dart';
import 'marketplace_models.dart';

/// Thrown by [MarketplaceRepository] for any failure a caller should
/// surface to the user. `isRetryableNetworkFailure` mirrors
/// `FieldRepositoryException`'s convention: true only for a timeout/no-
/// connection/unreachable-backend failure (no HTTP status at all) - never
/// for 401/403/404/409/422 (Task 22), which are definitive server
/// answers a cache must never paper over.
class MarketplaceRepositoryException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final bool isRetryableNetworkFailure;

  const MarketplaceRepositoryException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.isRetryableNetworkFailure = false,
  });

  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// FastAPI-backed access to `/marketplace/**`. Every method goes through
/// the shared [ApiClient] (no second Dio instance, no direct Supabase
/// table access - Supabase remains authentication only).
///
/// Reads may fall back to [MarketplaceCacheStore] on a retryable network
/// failure. Mutations (create/close listing, place/withdraw/accept bid)
/// NEVER read from or write a queued-for-later-replay cache entry -
/// Task 21's offline policy: inventory/bid state is too concurrency-
/// sensitive to guess at offline.
class MarketplaceRepository {
  const MarketplaceRepository(
    this._client, {
    MarketplaceCacheStore? cacheStore,
    String? Function()? scopeUserIdProvider,
  })  : _cacheStore = cacheStore,
        _scopeUserIdProvider = scopeUserIdProvider;

  final ApiClient _client;
  final MarketplaceCacheStore? _cacheStore;

  /// Reads the authenticated Supabase user id fresh on every call (never
  /// captured once at construction time), so a login/logout between two
  /// requests can never scope a read under the wrong - or a stale -
  /// user (Task 20). Null when not resolvable; private caches are never
  /// read/written without it.
  final String? Function()? _scopeUserIdProvider;

  String? get _scopeUserId => _scopeUserIdProvider?.call();

  MarketplaceRepositoryException _wrap(NetworkException error) {
    return MarketplaceRepositoryException(
      error.message,
      statusCode: error.statusCode,
      errorCode: error.errorCode,
      isRetryableNetworkFailure: error.statusCode == null,
    );
  }

  Future<T> _readWithCache<T>({
    required String cacheKey,
    required String? scope,
    required Future<dynamic> Function() request,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final response = await request();
      final json = Map<String, dynamic>.from(response as Map);
      if (_cacheStore != null) {
        await _cacheStore.put(cacheKey: cacheKey, scopeUserId: scope, payload: json);
      }
      return fromJson(json);
    } on NetworkException catch (error) {
      if (error.statusCode == null && _cacheStore != null) {
        final cached = await _cacheStore.get(cacheKey: cacheKey, scopeUserId: scope);
        if (cached != null) return fromJson(cached);
      }
      throw _wrap(error);
    }
  }

  String _browseCacheKey(Map<String, dynamic> query) {
    final sortedKeys = query.keys.toList()..sort();
    final parts = sortedKeys.map((k) => '$k=${query[k]}').join('&');
    return 'browse:$parts';
  }

  Future<MarketplacePage<MarketplaceListing>> browseListings({
    String? cursor,
    String? listingKind,
    String? productCode,
    String? countryCode,
    String? district,
    String? status,
    int? minPriceMinor,
    int? maxPriceMinor,
    int? limit,
  }) async {
    final query = <String, dynamic>{
      if (cursor != null) 'cursor': cursor,
      if (listingKind != null) 'listing_kind': listingKind,
      if (productCode != null) 'product_code': productCode,
      if (countryCode != null) 'country_code': countryCode,
      if (district != null) 'district': district,
      if (status != null) 'status': status,
      if (minPriceMinor != null) 'min_price_minor': minPriceMinor,
      if (maxPriceMinor != null) 'max_price_minor': maxPriceMinor,
      if (limit != null) 'limit': limit,
    };
    return _readWithCache(
      cacheKey: _browseCacheKey(query),
      scope: MarketplaceCacheStore.publicScope,
      request: () => _client.get(ApiEndpoints.marketplaceListings, queryParameters: query),
      fromJson: (json) => MarketplacePage.fromJson(json, MarketplaceListing.fromJson),
    );
  }

  Future<MarketplaceListing> fetchListing(String id) async {
    return _readWithCache(
      cacheKey: 'listing:$id',
      scope: MarketplaceCacheStore.publicScope,
      request: () => _client.get(ApiEndpoints.marketplaceListing(id)),
      fromJson: MarketplaceListing.fromJson,
    );
  }

  Future<MarketplacePage<MarketplaceListing>> fetchMyListings({String? cursor}) async {
    final query = {if (cursor != null) 'cursor': cursor};
    return _readWithCache(
      cacheKey: 'my-listings:${cursor ?? ''}',
      scope: _scopeUserId,
      request: () => _client.get(ApiEndpoints.marketplaceMyListings, queryParameters: query),
      fromJson: (json) => MarketplacePage.fromJson(json, MarketplaceListing.fromJson),
    );
  }

  /// Mutation - never cached, never queued offline (Task 21).
  Future<MarketplaceListing> createListing({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.marketplaceListings,
        data: payload,
        idempotencyKey: idempotencyKey,
      );
      return MarketplaceListing.fromJson(Map<String, dynamic>.from(response as Map));
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  /// Mutation - never cached, never queued offline.
  Future<MarketplaceListing> closeListing(String id) async {
    try {
      final response = await _client.post(ApiEndpoints.marketplaceListingClose(id));
      return MarketplaceListing.fromJson(Map<String, dynamic>.from(response as Map));
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  Future<MarketplacePage<MarketplaceBid>> fetchListingBids(
    String listingId, {
    String? cursor,
    String? sort,
  }) async {
    final query = {
      if (cursor != null) 'cursor': cursor,
      if (sort != null) 'sort': sort,
    };
    return _readWithCache(
      cacheKey: 'listing-bids:$listingId:${sort ?? ''}:${cursor ?? ''}',
      scope: _scopeUserId,
      request: () =>
          _client.get(ApiEndpoints.marketplaceListingBids(listingId), queryParameters: query),
      fromJson: (json) => MarketplacePage.fromJson(json, MarketplaceBid.fromJson),
    );
  }

  /// Mutation - never cached, never queued offline.
  Future<MarketplaceBid> placeBid({
    required String listingId,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.marketplaceListingBids(listingId),
        data: payload,
        idempotencyKey: idempotencyKey,
      );
      return MarketplaceBid.fromJson(Map<String, dynamic>.from(response as Map));
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  Future<MarketplacePage<MarketplaceBid>> fetchMyBids({String? cursor}) async {
    final query = {if (cursor != null) 'cursor': cursor};
    return _readWithCache(
      cacheKey: 'my-bids:${cursor ?? ''}',
      scope: _scopeUserId,
      request: () => _client.get(ApiEndpoints.marketplaceMyBids, queryParameters: query),
      fromJson: (json) => MarketplacePage.fromJson(json, MarketplaceBid.fromJson),
    );
  }

  /// Mutation - never cached, never queued offline.
  Future<MarketplaceBid> withdrawBid(String bidId) async {
    try {
      final response = await _client.post(ApiEndpoints.marketplaceBidWithdraw(bidId));
      return MarketplaceBid.fromJson(Map<String, dynamic>.from(response as Map));
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  /// Mutation - never cached, never queued offline. This is the one that
  /// matters most: never retried automatically (Task 17), and a 409 must
  /// reach the caller as-is so the UI can refresh real state (Task 22/41).
  Future<BidAcceptResult> acceptBid({
    required String bidId,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post(
        ApiEndpoints.marketplaceBidAccept(bidId),
        idempotencyKey: idempotencyKey,
      );
      return BidAcceptResult.fromJson(Map<String, dynamic>.from(response as Map));
    } on NetworkException catch (error) {
      throw _wrap(error);
    }
  }

  Future<MarketplacePage<MarketplaceOrder>> fetchOrders({
    String? cursor,
    String? role,
    String? status,
  }) async {
    final query = {
      if (cursor != null) 'cursor': cursor,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
    };
    return _readWithCache(
      cacheKey: 'orders:${role ?? ''}:${status ?? ''}:${cursor ?? ''}',
      scope: _scopeUserId,
      request: () => _client.get(ApiEndpoints.marketplaceOrders, queryParameters: query),
      fromJson: (json) => MarketplacePage.fromJson(json, MarketplaceOrder.fromJson),
    );
  }

  Future<MarketplaceOrder> fetchOrder(String id) async {
    return _readWithCache(
      cacheKey: 'order:$id',
      scope: _scopeUserId,
      request: () => _client.get(ApiEndpoints.marketplaceOrder(id)),
      fromJson: MarketplaceOrder.fromJson,
    );
  }
}
