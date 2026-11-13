import 'package:agri_guardian/core/network/api_client.dart';
import 'package:agri_guardian/features/fields/data/crop_cycle_repository.dart';
import 'package:agri_guardian/shared/models/crop_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(accessTokenProvider: () async => 'token');

  String? lastGetPath;
  Map<String, dynamic>? lastGetQueryParams;
  String? lastPostPath;
  Map<String, dynamic>? lastPostData;
  String? lastPostIdempotencyKey;
  String? lastPatchPath;
  Map<String, dynamic>? lastPatchData;

  dynamic getResponse;
  dynamic postResponse;
  dynamic patchResponse;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastGetPath = path;
    lastGetQueryParams = queryParameters;
    return getResponse;
  }

  @override
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? data,
    String? idempotencyKey,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    lastPostIdempotencyKey = idempotencyKey;
    return postResponse;
  }

  @override
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    lastPatchPath = path;
    lastPatchData = data;
    return patchResponse;
  }
}

Map<String, dynamic> _makeRawCycleJson({
  required String id,
  required String fieldId,
  String status = CropCycleStatus.active,
  int version = 1,
}) {
  return {
    'id': id,
    'field_id': fieldId,
    'crop_code': 'RICE_AMON',
    'variety': 'BRRI dhan28',
    'planting_date': '2026-06-15',
    'expected_harvest_date': '2026-10-15',
    'actual_harvest_date': null,
    'current_stage': 'VEGETATIVE',
    'irrigation_type': IrrigationType.rainfed,
    'status': status,
    'created_at': '2026-06-15T08:00:00Z',
    'updated_at': '2026-06-15T08:00:00Z',
    'version': version,
  };
}

void main() {
  group('CropCycleRepository Contract Tests', () {
    late FakeApiClient client;
    late CropCycleRepository repository;

    setUp(() {
      client = FakeApiClient();
      repository = CropCycleRepository(client);
    });

    test('fetchCyclesForField GETs /fields/{fieldId}/crop-cycles', () async {
      client.getResponse = {
        'items': [_makeRawCycleJson(id: 'cycle_1', fieldId: 'field_100')],
        'next_cursor': null,
        'has_more': false,
      };

      final cycles = await repository.fetchCyclesForField('field_100');

      expect(cycles, hasLength(1));
      expect(cycles[0].id, equals('cycle_1'));
      expect(client.lastGetPath, equals('/fields/field_100/crop-cycles'));
    });

    test('fetchCycle GETs /crop-cycles/{cycleId}', () async {
      client.getResponse = _makeRawCycleJson(id: 'cycle_1', fieldId: 'field_100');

      final cycle = await repository.fetchCycle('cycle_1');

      expect(cycle.id, equals('cycle_1'));
      expect(client.lastGetPath, equals('/crop-cycles/cycle_1'));
    });

    test('createCycle POSTs to /fields/{fieldId}/crop-cycles with idempotency key', () async {
      client.postResponse = _makeRawCycleJson(id: 'cycle_new', fieldId: 'field_100');

      final created = await repository.createCycle(
        fieldId: 'field_100',
        cropCode: 'RICE_AMON',
        idempotencyKey: 'idemp_cycle_456',
      );

      expect(created.id, equals('cycle_new'));
      expect(client.lastPostPath, equals('/fields/field_100/crop-cycles'));
      expect(client.lastPostIdempotencyKey, equals('idemp_cycle_456'));
    });

    test('updateCycle PATCHes /crop-cycles/{cycleId} carrying expected_version', () async {
      client.patchResponse = _makeRawCycleJson(
        id: 'cycle_1',
        fieldId: 'field_100',
        status: CropCycleStatus.harvested,
        version: 2,
      );

      final updated = await repository.updateCycle(
        cycleId: 'cycle_1',
        status: CropCycleStatus.harvested,
        expectedVersion: 1,
      );

      expect(updated.status, equals(CropCycleStatus.harvested));
      expect(client.lastPatchPath, equals('/crop-cycles/cycle_1'));
      expect(client.lastPatchData!['expected_version'], equals(1));
    });
  });
}

