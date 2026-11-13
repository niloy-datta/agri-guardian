import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_guardian/core/storage/app_database.dart';
import 'package:agri_guardian/core/network/api_client.dart';
import 'package:agri_guardian/core/network/connectivity_service.dart';
import 'package:agri_guardian/core/network/network_exception.dart';
import 'package:agri_guardian/features/fields/data/field_repository.dart';
import 'package:agri_guardian/features/fields/data/crop_cycle_repository.dart';
import 'package:agri_guardian/features/fields/data/offline/field_cache_store.dart';
import 'package:agri_guardian/features/fields/data/offline/crop_cycle_cache_store.dart';
import 'package:agri_guardian/shared/models/field.dart';
import 'package:agri_guardian/shared/models/crop_cycle.dart';

class MockApiClient implements ApiClient {
  bool shouldFail = false;
  int? failureStatusCode;
  String? failureErrorCode;

  @override
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (shouldFail) {
      throw NetworkException(
        'Network error',
        failureStatusCode,
        failureErrorCode,
      );
    }
    if (endpoint == '/fields') {
      return {
        'items': [
          {
            'id': 'f-remote-1',
            'farmer_id': 'usr-1',
            'name': 'Remote Field',
            'boundary': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [90.0, 24.0],
                  [90.1, 24.0],
                  [90.1, 24.1],
                  [90.0, 24.1],
                  [90.0, 24.0]
                ]
              ]
            },
            'centroid': {
              'longitude': 90.05,
              'latitude': 24.05,
            },
            'area_sq_m': 10000.0,
            'area_acres': 2.47,
            'country_code': 'BD',
            'status': 'ACTIVE',
            'version': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        ],
        'next_cursor': null,
        'has_more': false,
      };
    } else if (endpoint.contains('/crop-cycles')) {
      return {
        'items': [
          {
            'id': 'cc-remote-1',
            'field_id': 'f-remote-1',
            'crop_code': 'RICE_BORO',
            'status': 'PLANNED',
            'version': 1,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        ],
        'next_cursor': null,
        'has_more': false,
      };
    }
    throw UnimplementedError('Endpoint not mocked: $endpoint');
  }

  @override
  Future<dynamic> post(String endpoint, {dynamic data, String? idempotencyKey}) async {
    if (shouldFail) {
      throw NetworkException(
        'Network error',
        failureStatusCode,
        failureErrorCode,
      );
    }
    throw UnimplementedError('Endpoint not mocked: $endpoint');
  }

  @override
  Future<dynamic> patch(String endpoint, {dynamic data}) async {
    throw UnimplementedError();
  }

}

class MockConnectivityService implements ConnectivityService {
  bool isOnline = true;

  @override
  Future<bool> isConnected() async => isOnline;

  @override
  Stream<bool> onConnectivityChanged() => Stream.value(isOnline);
}

void main() {
  late AppDatabase db;
  late FieldCacheStore fieldCacheStore;
  late CropCycleCacheStore cropCycleCacheStore;
  late MockApiClient apiClient;
  late MockConnectivityService connectivityService;
  late FieldRepository fieldRepository;
  late CropCycleRepository cropCycleRepository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fieldCacheStore = FieldCacheStore(db);
    cropCycleCacheStore = CropCycleCacheStore(db);
    apiClient = MockApiClient();
    connectivityService = MockConnectivityService();
    fieldRepository = FieldRepository(
      apiClient,
      cacheStore: fieldCacheStore,
      connectivityService: connectivityService,
    );
    cropCycleRepository = CropCycleRepository(
      apiClient,
      cacheStore: cropCycleCacheStore,
      connectivityService: connectivityService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Offline Fallback Repository Tests', () {
    test('fetchFields fetches from remote and caches result when online', () async {
      final fields = await fieldRepository.fetchFields();
      expect(fields.length, equals(1));
      expect(fields.first.id, equals('f-remote-1'));

      final cached = await fieldCacheStore.getAllFields();
      expect(cached.length, equals(1));
      expect(cached.first.id, equals('f-remote-1'));
    });

    test('fetchFields returns cached fields when offline', () async {
      await fieldCacheStore.upsertField(
        Field.fromJson({
          'id': 'f-cached-1',
          'farmer_id': 'usr-1',
          'name': 'Cached Field',
          'boundary': {
            'type': 'Polygon',
            'coordinates': [
              [
                [90.0, 24.0],
                [90.1, 24.0],
                [90.1, 24.1],
                [90.0, 24.1],
                [90.0, 24.0]
              ]
            ]
          },
          'centroid': {
            'longitude': 90.05,
            'latitude': 24.05,
          },
          'area_sq_m': 5000.0,
          'area_acres': 1.23,
          'country_code': 'BD',
          'status': 'ACTIVE',
          'version': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      connectivityService.isOnline = false;

      final fields = await fieldRepository.fetchFields();
      expect(fields.length, equals(1));
      expect(fields.first.id, equals('f-cached-1'));
      expect(fields.first.name, equals('Cached Field'));
    });

    test('fetchCyclesForField returns cached crop cycles when offline', () async {
      await cropCycleCacheStore.upsertCycle(
        CropCycle.fromJson({
          'id': 'cc-cached-1',
          'field_id': 'f-1',
          'crop_code': 'WHEAT',
          'status': 'PLANNED',
          'version': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      connectivityService.isOnline = false;

      final cycles = await cropCycleRepository.fetchCyclesForField('f-1');
      expect(cycles.length, equals(1));
      expect(cycles.first.cropCode, equals('WHEAT'));
    });
  });
}
