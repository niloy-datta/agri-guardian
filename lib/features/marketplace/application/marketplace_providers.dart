import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/fields/application/fields_providers.dart'
    show apiClientProvider, appDatabaseProvider, connectivityServiceProvider;
import '../../../services/firebase_service.dart';
import '../data/commerce_operation_store.dart';
import '../data/exact_numbers.dart';
import '../data/marketplace_cache_store.dart';
import '../data/marketplace_models.dart';
import '../data/marketplace_repository.dart';

/// Reused from `fields_providers.dart` rather than re-declared: one
/// `AppDatabase`, one `ApiClient`, one `ConnectivityService` for the
/// whole app (Task 23: never a second Dio instance).
export '../../../features/fields/application/fields_providers.dart'
    show apiClientProvider, appDatabaseProvider, connectivityServiceProvider;

final marketplaceCacheStoreProvider = Provider<MarketplaceCacheStore>((ref) {
  return MarketplaceCacheStore(ref.watch(appDatabaseProvider));
});

final commerceOperationStoreProvider = Provider<CommerceOperationStore>((ref) {
  return CommerceOperationStore(ref.watch(appDatabaseProvider));
});

/// The current Supabase user id, or null - read fresh, never cached in
/// provider state, so it can never go stale across a login/logout.
String? currentScopeUserId() => FirebaseService.instance.currentUser?.uid;

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(
    ref.watch(apiClientProvider),
    cacheStore: ref.watch(marketplaceCacheStoreProvider),
    scopeUserIdProvider: currentScopeUserId,
  );
});

/// True when the device currently has no usable network interface -
/// mutation buttons must disable themselves on this (Task 21), not just
/// on an eventual request failure.
final isOfflineProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(connectivityServiceProvider)
      .onConnectivityChanged()
      .map((c) => !c);
});

// ============================================================
// Browse listings
// ============================================================

class BrowseFilters {
  final String? listingKind;
  final String? district;
  final int? minPriceMinor;
  final int? maxPriceMinor;

  const BrowseFilters({
    this.listingKind,
    this.district,
    this.minPriceMinor,
    this.maxPriceMinor,
  });

  BrowseFilters copyWith({
    String? listingKind,
    bool clearListingKind = false,
    String? district,
    bool clearDistrict = false,
    int? minPriceMinor,
    int? maxPriceMinor,
  }) {
    return BrowseFilters(
      listingKind: clearListingKind ? null : (listingKind ?? this.listingKind),
      district: clearDistrict ? null : (district ?? this.district),
      minPriceMinor: minPriceMinor ?? this.minPriceMinor,
      maxPriceMinor: maxPriceMinor ?? this.maxPriceMinor,
    );
  }
}

final browseFiltersProvider = StateProvider<BrowseFilters>(
  (ref) => const BrowseFilters(),
);

class BrowseListingsState {
  final List<MarketplaceListing> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isOfflineCache;

  const BrowseListingsState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isOfflineCache = false,
  });

  BrowseListingsState copyWith({
    List<MarketplaceListing>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isOfflineCache,
  }) {
    return BrowseListingsState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isOfflineCache: isOfflineCache ?? this.isOfflineCache,
    );
  }
}

/// Browse-tab controller: real incremental pagination (Task 24), never
/// "fetch every page up front". Guards against duplicate load-more calls
/// and de-duplicates by server id defensively.
class BrowseListingsController
    extends AutoDisposeAsyncNotifier<BrowseListingsState> {
  @override
  Future<BrowseListingsState> build() async {
    ref.watch(browseFiltersProvider);
    return _fetchFirstPage();
  }

  Future<BrowseListingsState> _fetchFirstPage() async {
    final filters = ref.read(browseFiltersProvider);
    final repo = ref.read(marketplaceRepositoryProvider);
    final page = await repo.browseListings(
      listingKind: filters.listingKind,
      district: filters.district,
      minPriceMinor: filters.minPriceMinor,
      maxPriceMinor: filters.maxPriceMinor,
    );
    return BrowseListingsState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchFirstPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final filters = ref.read(browseFiltersProvider);
      final repo = ref.read(marketplaceRepositoryProvider);
      final page = await repo.browseListings(
        cursor: current.nextCursor,
        listingKind: filters.listingKind,
        district: filters.district,
        minPriceMinor: filters.minPriceMinor,
        maxPriceMinor: filters.maxPriceMinor,
      );
      final seenIds = current.items.map((item) => item.id).toSet();
      final newItems = page.items.where((item) => !seenIds.contains(item.id));
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...newItems],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }
}

final browseListingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      BrowseListingsController,
      BrowseListingsState
    >(BrowseListingsController.new);

// ============================================================
// Listing detail
// ============================================================

final listingDetailProvider = FutureProvider.autoDispose
    .family<MarketplaceListing, String>((ref, listingId) {
      return ref.watch(marketplaceRepositoryProvider).fetchListing(listingId);
    });

// ============================================================
// My listings (seller)
// ============================================================

final myListingsControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      MyListingsController,
      List<MarketplaceListing>
    >(MyListingsController.new);

class MyListingsController
    extends AutoDisposeAsyncNotifier<List<MarketplaceListing>> {
  @override
  Future<List<MarketplaceListing>> build() async {
    final page = await ref
        .read(marketplaceRepositoryProvider)
        .fetchMyListings();
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(marketplaceRepositoryProvider)
          .fetchMyListings();
      return page.items;
    });
  }
}

// ============================================================
// Create / close listing
// ============================================================

/// Idempotent listing creation (Task 16/17/37): the idempotency key is
/// persisted in [CommerceOperationStore] before the request is sent, and
/// reused verbatim on a retry of the exact same payload.
class CreateListingController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<MarketplaceListing> submit(Map<String, dynamic> payload) async {
    final scopeUserId = currentScopeUserId();
    if (scopeUserId == null) {
      throw const MarketplaceRepositoryException('সাইন ইন করা প্রয়োজন।');
    }
    final store = ref.read(commerceOperationStoreProvider);
    final key = await store.begin(
      scopeUserId: scopeUserId,
      type: CommerceOperationType.createListing,
      payload: payload,
    );

    state = const AsyncLoading();
    try {
      final listing = await ref
          .read(marketplaceRepositoryProvider)
          .createListing(payload: payload, idempotencyKey: key);
      await store.complete(key);
      state = const AsyncData(null);
      ref.invalidate(myListingsControllerProvider);
      ref.invalidate(browseListingsControllerProvider);
      return listing;
    } on MarketplaceRepositoryException catch (error) {
      if (!error.isRetryableNetworkFailure) {
        // Definitive server answer (4xx) - this exact request will never
        // succeed as-is, so the pending record is resolved, not kept.
        await store.complete(key);
      }
      state = AsyncError(error, StackTrace.current);
      rethrow;
    }
  }
}

final createListingControllerProvider =
    AutoDisposeAsyncNotifierProvider<CreateListingController, void>(
      CreateListingController.new,
    );

class CloseListingController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<MarketplaceListing> submit(String listingId) async {
    state = const AsyncLoading();
    try {
      final listing = await ref
          .read(marketplaceRepositoryProvider)
          .closeListing(listingId);
      state = const AsyncData(null);
      ref.invalidate(myListingsControllerProvider);
      ref.invalidate(browseListingsControllerProvider);
      ref.invalidate(listingDetailProvider(listingId));
      return listing;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final closeListingControllerProvider =
    AutoDisposeAsyncNotifierProvider<CloseListingController, void>(
      CloseListingController.new,
    );

// ============================================================
// Seller bid inbox
// ============================================================

final sellerBidInboxSortProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final sellerBidInboxProvider = FutureProvider.autoDispose
    .family<List<MarketplaceBid>, String>((ref, listingId) async {
      final sort = ref.watch(sellerBidInboxSortProvider);
      final page = await ref
          .read(marketplaceRepositoryProvider)
          .fetchListingBids(listingId, sort: sort);
      return page.items;
    });

// ============================================================
// Place / withdraw bid
// ============================================================

class PlaceBidController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<MarketplaceBid> submit({
    required String listingId,
    required String quantity,
    required int unitPriceMinor,
    required String currency,
    String? note,
    DateTime? expiresAt,
  }) async {
    normalizeQuantityInput(
      quantity,
    ); // throws ExactNumberFormatException if invalid

    final scopeUserId = currentScopeUserId();
    if (scopeUserId == null) {
      throw const MarketplaceRepositoryException('সাইন ইন করা প্রয়োজন।');
    }
    final payload = {
      'quantity': quantity,
      'unit_price_minor': unitPriceMinor,
      'currency': currency,
      if (note != null && note.isNotEmpty) 'note': note,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
    };

    final store = ref.read(commerceOperationStoreProvider);
    final key = await store.begin(
      scopeUserId: scopeUserId,
      type: CommerceOperationType.placeBid,
      resourceId: listingId,
      payload: payload,
    );

    state = const AsyncLoading();
    try {
      final bid = await ref
          .read(marketplaceRepositoryProvider)
          .placeBid(
            listingId: listingId,
            payload: payload,
            idempotencyKey: key,
          );
      await store.complete(key);
      state = const AsyncData(null);
      ref.invalidate(myBidsControllerProvider);
      ref.invalidate(listingDetailProvider(listingId));
      return bid;
    } on MarketplaceRepositoryException catch (error) {
      if (!error.isRetryableNetworkFailure) {
        await store.complete(key);
      }
      state = AsyncError(error, StackTrace.current);
      rethrow;
    }
  }
}

final placeBidControllerProvider =
    AutoDisposeAsyncNotifierProvider<PlaceBidController, void>(
      PlaceBidController.new,
    );

final myBidsControllerProvider =
    AutoDisposeAsyncNotifierProvider<MyBidsController, List<MarketplaceBid>>(
      MyBidsController.new,
    );

class MyBidsController extends AutoDisposeAsyncNotifier<List<MarketplaceBid>> {
  @override
  Future<List<MarketplaceBid>> build() async {
    final page = await ref.read(marketplaceRepositoryProvider).fetchMyBids();
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(marketplaceRepositoryProvider).fetchMyBids();
      return page.items;
    });
  }
}

class WithdrawBidController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<MarketplaceBid> submit(String bidId) async {
    state = const AsyncLoading();
    try {
      final bid = await ref
          .read(marketplaceRepositoryProvider)
          .withdrawBid(bidId);
      state = const AsyncData(null);
      ref.invalidate(myBidsControllerProvider);
      return bid;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final withdrawBidControllerProvider =
    AutoDisposeAsyncNotifierProvider<WithdrawBidController, void>(
      WithdrawBidController.new,
    );

// ============================================================
// Accept bid
// ============================================================

/// Task 26's invalidation matrix for acceptance: seller bid inbox, my
/// listings, listing detail, and orders all refresh - server response is
/// truth, never a locally-guessed final inventory state.
class AcceptBidController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<BidAcceptResult> submit({
    required String bidId,
    required String listingId,
  }) async {
    final scopeUserId = currentScopeUserId();
    if (scopeUserId == null) {
      throw const MarketplaceRepositoryException('সাইন ইন করা প্রয়োজন।');
    }
    final store = ref.read(commerceOperationStoreProvider);
    final key = await store.begin(
      scopeUserId: scopeUserId,
      type: CommerceOperationType.acceptBid,
      resourceId: bidId,
      payload: {'bid_id': bidId},
    );

    state = const AsyncLoading();
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .acceptBid(bidId: bidId, idempotencyKey: key);
      await store.complete(key);
      state = const AsyncData(null);
      ref.invalidate(sellerBidInboxProvider(listingId));
      ref.invalidate(myListingsControllerProvider);
      ref.invalidate(listingDetailProvider(listingId));
      ref.invalidate(ordersControllerProvider);
      return result;
    } on MarketplaceRepositoryException catch (error) {
      if (!error.isRetryableNetworkFailure) {
        // Includes 409: a definitive "no" from the server, never kept as
        // if it might still succeed later (Task 41).
        await store.complete(key);
        ref.invalidate(sellerBidInboxProvider(listingId));
        ref.invalidate(listingDetailProvider(listingId));
      }
      state = AsyncError(error, StackTrace.current);
      rethrow;
    }
  }
}

final acceptBidControllerProvider =
    AutoDisposeAsyncNotifierProvider<AcceptBidController, void>(
      AcceptBidController.new,
    );

// ============================================================
// Orders
// ============================================================

final orderRoleFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final ordersControllerProvider =
    AutoDisposeAsyncNotifierProvider<OrdersController, List<MarketplaceOrder>>(
      OrdersController.new,
    );

class OrdersController
    extends AutoDisposeAsyncNotifier<List<MarketplaceOrder>> {
  @override
  Future<List<MarketplaceOrder>> build() async {
    final role = ref.watch(orderRoleFilterProvider);
    final page = await ref
        .read(marketplaceRepositoryProvider)
        .fetchOrders(role: role);
    return page.items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final role = ref.read(orderRoleFilterProvider);
      final page = await ref
          .read(marketplaceRepositoryProvider)
          .fetchOrders(role: role);
      return page.items;
    });
  }
}

final orderDetailProvider = FutureProvider.autoDispose
    .family<MarketplaceOrder, String>((ref, orderId) {
      return ref.watch(marketplaceRepositoryProvider).fetchOrder(orderId);
    });
