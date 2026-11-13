import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_guardian/core/storage/app_database.dart';
import 'package:agri_guardian/features/marketplace/data/marketplace_cache_store.dart';

/// Focused regression coverage for Task 7/18 (12B.0): private marketplace
/// caches (my-listings, my-bids, orders) must stay scoped to the
/// authenticated Supabase user. User A must never read User B's private
/// cache, even sharing the same `cacheKey` on one device.
void main() {
  late AppDatabase db;
  late MarketplaceCacheStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = MarketplaceCacheStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MarketplaceCacheStore private cache isolation', () {
    test(
      'a private cache written for user A is not returned to user B',
      () async {
        await store.put(
          cacheKey: 'my-listings:',
          scopeUserId: 'user-A',
          payload: {'items': 'user A data'},
        );

        final userBRead = await store.get(
          cacheKey: 'my-listings:',
          scopeUserId: 'user-B',
        );
        expect(userBRead, isNull);

        final userARead = await store.get(
          cacheKey: 'my-listings:',
          scopeUserId: 'user-A',
        );
        expect(userARead, isNotNull);
        expect(userARead!['items'], equals('user A data'));
      },
    );

    test('a private cache is not returned when no user is signed in', () async {
      await store.put(
        cacheKey: 'my-bids:',
        scopeUserId: 'user-A',
        payload: {'items': 'user A bids'},
      );

      final anonymousRead = await store.get(
        cacheKey: 'my-bids:',
        scopeUserId: null,
      );
      expect(anonymousRead, isNull);
    });

    test(
      'the public browse cache (null scope) is readable by anyone',
      () async {
        await store.put(
          cacheKey: 'browse:',
          scopeUserId: MarketplaceCacheStore.publicScope,
          payload: {'items': 'public listings'},
        );

        final read = await store.get(
          cacheKey: 'browse:',
          scopeUserId: MarketplaceCacheStore.publicScope,
        );
        expect(read, isNotNull);
        expect(read!['items'], equals('public listings'));
      },
    );

    test('a second write for a different user to the same key never leaks '
        "the first user's data once overwritten", () async {
      await store.put(
        cacheKey: 'orders:',
        scopeUserId: 'user-A',
        payload: {'items': 'user A orders'},
      );
      // Same cache key, different scope - e.g. account switch on a shared
      // device. The row is replaced, not merged.
      await store.put(
        cacheKey: 'orders:',
        scopeUserId: 'user-B',
        payload: {'items': 'user B orders'},
      );

      final userARead = await store.get(
        cacheKey: 'orders:',
        scopeUserId: 'user-A',
      );
      expect(userARead, isNull);

      final userBRead = await store.get(
        cacheKey: 'orders:',
        scopeUserId: 'user-B',
      );
      expect(userBRead!['items'], equals('user B orders'));
    });

    test(
      'clearAllForUser removes only that user\'s private cache rows',
      () async {
        await store.put(
          cacheKey: 'my-listings:',
          scopeUserId: 'user-A',
          payload: {'items': 'A'},
        );
        await store.put(
          cacheKey: 'my-bids:',
          scopeUserId: 'user-A',
          payload: {'items': 'A'},
        );
        await store.put(
          cacheKey: 'my-listings:other',
          scopeUserId: 'user-B',
          payload: {'items': 'B'},
        );

        await store.clearAllForUser('user-A');

        expect(
          await store.get(cacheKey: 'my-listings:', scopeUserId: 'user-A'),
          isNull,
        );
        expect(
          await store.get(cacheKey: 'my-bids:', scopeUserId: 'user-A'),
          isNull,
        );
        expect(
          await store.get(cacheKey: 'my-listings:other', scopeUserId: 'user-B'),
          isNotNull,
        );
      },
    );
  });
}
