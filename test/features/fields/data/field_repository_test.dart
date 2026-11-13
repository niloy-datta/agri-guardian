import 'package:agri_guardian/core/network/api_client.dart';
import 'package:agri_guardian/features/fields/data/field_repository.dart';
import 'package:agri_guardian/shared/models/field.dart';
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
  List<dynamic>? getSequence;
  int sequenceIndex = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastGetPath = path;
    lastGetQueryParams = queryParameters;
    if (getSequence != null && sequenceIndex < getSequence!.length) {
      return getSequence![sequenceIndex++];
    }
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

Map<String, dynamic> _makeRawFieldJson({
  required String id,
  required String name,
  String status = FieldStatus.active,
  int version = 1,
}) {
  return {
    'id': id,
    'farmer_id': 'farmer_1',
    'name': name,
    'boundary': {
      'type': 'Polygon',
      'coordinates': [
        [
          [90.4125, 23.8103],
          [90.4130, 23.8105],
          [90.4135, 23.8100],
          [90.4125, 23.8103],
        ]
      ],
    },
    'centroid': {'longitude': 90.4130, 'latitude': 23.8102},
    'area_sq_m': 1000.0,
    'area_acres': 0.25,
    'country_code': 'BD',
    'status': status,
    'created_at': '2026-09-20T10:00:00Z',
    'updated_at': '2026-09-20T10:00:00Z',
    'version': version,
  };
}

void main() {
  group('FieldRepository Contract Tests', () {
    late FakeApiClient client;
    late FieldRepository repository;

    setUp(() {
      client = FakeApiClient();
      repository = FieldRepository(client);
    });

    test('fetchFields drains cursor pagination pages until has_more is false', () async {
      client.getSequence = [
        {
          'items': [_makeRawFieldJson(id: 'field_1', name: 'Field One')],
          'next_cursor': 'cursor_page_2',
          'has_more': true,
        },
        {
          'items': [_makeRawFieldJson(id: 'field_2', name: 'Field Two')],
          'next_cursor': null,
          'has_more': false,
        },
      ];

      final fields = await repository.fetchFields();

      expect(fields, hasLength(2));
      expect(fields[0].id, equals('field_1'));
      expect(fields[1].id, equals('field_2'));
      expect(client.sequenceIndex, equals(2));
    });

    test('createField posts to /fields and forwards idempotency key', () async {
      final sampleFieldJson = _makeRawFieldJson(id: 'field_new', name: 'Paddy North');
      client.postResponse = sampleFieldJson;

      final created = await repository.createField(
        name: 'Paddy North',
        boundary: {
          'type': 'Polygon',
          'coordinates': [
            [
              [90.4125, 23.8103],
              [90.4130, 23.8105],
              [90.4135, 23.8100],
              [90.4125, 23.8103],
            ]
          ],
        },
        countryCode: 'BD',
        idempotencyKey: 'idemp_field_123',
      );

      expect(created.id, equals('field_new'));
      expect(client.lastPostPath, equals('/fields'));
      expect(client.lastPostIdempotencyKey, equals('idemp_field_123'));
      expect(client.lastPostData!['name'], equals('Paddy North'));
    });

    test('archiveField sends PATCH with status ARCHIVED and expected_version', () async {
      client.patchResponse = _makeRawFieldJson(
        id: 'field_1',
        name: 'Field One',
        status: FieldStatus.archived,
        version: 2,
      );

      final archived = await repository.archiveField(
        id: 'field_1',
        expectedVersion: 1,
      );

      expect(archived.status, equals(FieldStatus.archived));
      expect(archived.version, equals(2));
      expect(client.lastPatchPath, equals('/fields/field_1'));
      expect(client.lastPatchData!['status'], equals(FieldStatus.archived));
      expect(client.lastPatchData!['expected_version'], equals(1));
    });
  });
}

