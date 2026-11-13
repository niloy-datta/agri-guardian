import 'package:agri_guardian/shared/models/crop_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CropCycle Model Tests', () {
    final sampleJson = {
      'id': 'cycle_uuid_505',
      'field_id': 'field_uuid_101',
      'crop_code': 'RICE_AMON',
      'variety': 'BRRI dhan28',
      'planting_date': '2026-06-15',
      'expected_harvest_date': '2026-10-15',
      'actual_harvest_date': null,
      'current_stage': 'VEGETATIVE',
      'irrigation_type': IrrigationType.rainfed,
      'status': CropCycleStatus.active,
      'created_at': '2026-06-15T08:00:00Z',
      'updated_at': '2026-07-01T10:00:00Z',
      'version': 1,
    };

    test('CropCycle.fromJson decodes complete CropCycleRead payload', () {
      final cycle = CropCycle.fromJson(sampleJson);

      expect(cycle.id, equals('cycle_uuid_505'));
      expect(cycle.fieldId, equals('field_uuid_101'));
      expect(cycle.cropCode, equals('RICE_AMON'));
      expect(cycle.variety, equals('BRRI dhan28'));
      expect(cycle.plantingDate, equals(DateTime(2026, 6, 15)));
      expect(cycle.expectedHarvestDate, equals(DateTime(2026, 10, 15)));
      expect(cycle.actualHarvestDate, isNull);
      expect(cycle.currentStage, equals('VEGETATIVE'));
      expect(cycle.irrigationType, equals(IrrigationType.rainfed));
      expect(cycle.status, equals(CropCycleStatus.active));
      expect(cycle.version, equals(1));
    });

    test('CropCycle.toCreateJson formats dates as YYYY-MM-DD strings', () {
      final createJson = CropCycle.toCreateJson(
        cropCode: 'RICE_AMON',
        variety: 'BRRI dhan28',
        plantingDate: DateTime(2026, 6, 15),
        expectedHarvestDate: DateTime(2026, 10, 15),
        irrigationType: IrrigationType.rainfed,
        status: CropCycleStatus.planned,
      );

      expect(createJson['crop_code'], equals('RICE_AMON'));
      expect(createJson['variety'], equals('BRRI dhan28'));
      expect(createJson['planting_date'], equals('2026-06-15'));
      expect(createJson['expected_harvest_date'], equals('2026-10-15'));
      expect(createJson['irrigation_type'], equals('RAINFED'));
      expect(createJson['status'], equals('PLANNED'));
    });

    test('CropCycle.toUpdateJson carries expected_version and formatted dates', () {
      final updateJson = CropCycle.toUpdateJson(
        actualHarvestDate: DateTime(2026, 10, 12),
        status: CropCycleStatus.harvested,
        expectedVersion: 2,
      );

      expect(updateJson['actual_harvest_date'], equals('2026-10-12'));
      expect(updateJson['status'], equals(CropCycleStatus.harvested));
      expect(updateJson['expected_version'], equals(2));
    });
  });
}

