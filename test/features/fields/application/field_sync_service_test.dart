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
import 'package:agri_guardian/features/fields/data/offline/sync_queue_store.dart';
import 'package:agri_guardian/features/fields/application/field_sync_service.dart';

class SyncTestApiClient implements ApiClient {
  int postCallCount = 0;
  bool shouldReturnConflict = false;
  bool shouldReturnBlocked = false;

  final List<Map<String, dynamic>> createdFields = [];
  final List<Map<String, dynamic>> createdCycles = [];

  @override
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    if (endpoint == '/fields') {
      return {
        'items': createdFields,
        'next_cursor': null,
        'has_more': false,
      };
    } else if (endpoint.contains('/crop-cycles')) {
      final parts = endpoint.split('/');
      final fieldId = parts[2];
      final items = createdCycles.where((c) => c['field_id'] == fieldId).toList();
      return {
        'items': items,
        'next_cursor': null,
        'has_more': false,
      };
    }
    return {'items': [], 'next_cursor': null, 'has_more': false};
  }

  @override
  Future<dynamic> post(String endpoint, {dynamic data, String? idempotencyKey}) async {
    postCallCount++;
    if (shouldReturnConflict) {
      throw const NetworkException('Idempotency conflict', 409);
    }
    if (shouldReturnBlocked) {
      throw const NetworkException('Validation error', 422);
    }

    if (endpoint == '/fields') {
      final fieldObj = {
        'id': 'f-server-999',
        'farmer_id': 'usr-1',
        'name': data['name'],
        'boundary': data['boundary'],
        'centroid': {'longitude': 90.05, 'latitude': 24.05},
        'area_sq_m': 10000.0,
        'area_acres': 2.47,
        'country_code': data['country_code'] ?? 'BD',
        'status': 'ACTIVE',
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      createdFields.add(fieldObj);
      return fieldObj;
    } else if (endpoint.contains('/crop-cycles')) {
      final parts = endpoint.split('/');
      final fieldId = parts[2];
      final cycleObj = {
        'id': 'cc-server-888',
        'field_id': fieldId,
        'crop_code': data['crop_code'],
        'status': 'PLANNED',
        'version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      createdCycles.add(cycleObj);
      return cycleObj;
    }
    throw UnimplementedError('Endpoint not mocked: $endpoint');
  }

  @override
  Future<dynamic> patch(String endpoint, {dynamic data}) async {
    throw UnimplementedError();
  }

}

class SyncTestConnectivity implements ConnectivityService {
  @override
  Future<bool> isConnected() async => true;

  @override
  Stream<bool> onConnectivityChanged() => Stream.value(true);
}

void main() {
  late AppDatabase db;
  late SyncQueueStore syncQueueStore;
  late FieldCacheStore fieldCacheStore;
  late CropCycleCacheStore cropCycleCacheStore;
  late SyncTestApiClient apiClient;
  late FieldSyncService syncService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    syncQueueStore = SyncQueueStore(db);
    fieldCacheStore = FieldCacheStore(db);
    cropCycleCacheStore = CropCycleCacheStore(db);
    apiClient = SyncTestApiClient();

    final connectivity = SyncTestConnectivity();
    final fieldRepo = FieldRepository(apiClient, cacheStore: fieldCacheStore, connectivityService: connectivity);
    final cropRepo = CropCycleRepository(apiClient, cacheStore: cropCycleCacheStore, connectivityService: connectivity);

    syncService = FieldSyncService(
      fieldRepository: fieldRepo,
      cropCycleRepository: cropRepo,
      syncQueueStore: syncQueueStore,
      fieldCacheStore: fieldCacheStore,
      cropCycleCacheStore: cropCycleCacheStore,
      connectivityService: connectivity,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('FieldSyncService Pass & Dependency Resolution Tests', () {
    test('syncs field_create and dependent crop_cycle_create with tempId resolution', () async {
      const tempFieldId = 'temp_field_123';

      await syncQueueStore.enqueue(
        type: 'field_create',
        payloadJson: '{"name":"North Field","boundary":{"type":"Polygon","coordinates":[[[90.0,24.0],[90.1,24.0],[90.1,24.1],[90.0,24.1],[90.0,24.0]]]},"country_code":"BD"}',
        idempotencyKey: 'idemp-f1',
        customMutationId: tempFieldId,
      );

      await syncQueueStore.enqueue(
        type: 'crop_cycle_create',
        payloadJson: '{"field_id":"temp_field_123","crop_code":"RICE_BORO"}',
        idempotencyKey: 'idemp-c1',
        customMutationId: 'temp_crop_456',
        parentMutationId: tempFieldId,
      );

      final result = await syncService.syncPendingMutations();

      expect(result.syncedCount, equals(2));
      expect(result.pendingRemainingCount, equals(0));

      final allMutations = await syncQueueStore.getAllMutations();
      expect(allMutations.every((m) => m.status == 'completed'), isTrue);

      final fieldMutation = allMutations.firstWhere((m) => m.type == 'field_create');
      expect(fieldMutation.resolvedServerId, equals('f-server-999'));

      final cachedFields = await fieldCacheStore.getAllFields();
      expect(cachedFields.length, equals(1));
      expect(cachedFields.first.id, equals('f-server-999'));

      final cachedCycles = await cropCycleCacheStore.getCyclesForField('f-server-999');
      expect(cachedCycles.length, equals(1));
      expect(cachedCycles.first.cropCode, equals('RICE_BORO'));
    });

    test('marks 409 error as conflict status', () async {
      apiClient.shouldReturnConflict = true;

      await syncQueueStore.enqueue(
        type: 'field_create',
        payloadJson: '{"name":"North Field","boundary":{"type":"Polygon","coordinates":[[[90.0,24.0],[90.1,24.0],[90.1,24.1],[90.0,24.1],[90.0,24.0]]]},"country_code":"BD"}',
        idempotencyKey: 'idemp-conflict',
      );

      final result = await syncService.syncPendingMutations();

      expect(result.syncedCount, equals(0));
      expect(result.conflictCount, equals(1));

      final mutations = await syncQueueStore.getAllMutations();
      expect(mutations.first.status, equals('conflict'));
    });

    test('marks 422 error as blocked status', () async {
      apiClient.shouldReturnBlocked = true;

      await syncQueueStore.enqueue(
        type: 'field_create',
        payloadJson: '{"name":"Invalid Field","boundary":{"type":"Polygon","coordinates":[]},"country_code":"BD"}',
        idempotencyKey: 'idemp-blocked',
      );

      final result = await syncService.syncPendingMutations();

      expect(result.syncedCount, equals(0));
      expect(result.blockedCount, equals(1));

      final mutations = await syncQueueStore.getAllMutations();
      expect(mutations.first.status, equals('blocked'));
    });
  });
}
