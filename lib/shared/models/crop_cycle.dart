/// Mirrors `CropCycleStatus` (`backend/api/app/shared/enums.py`).
class CropCycleStatus {
  CropCycleStatus._();

  static const String planned = 'PLANNED';
  static const String active = 'ACTIVE';
  static const String harvested = 'HARVESTED';
  static const String failed = 'FAILED';
  static const String cancelled = 'CANCELLED';
}

/// Mirrors `IrrigationType` (`backend/api/app/shared/enums.py`).
class IrrigationType {
  IrrigationType._();

  static const String rainfed = 'RAINFED';
  static const String flood = 'FLOOD';
  static const String furrow = 'FURROW';
  static const String sprinkler = 'SPRINKLER';
  static const String drip = 'DRIP';
  static const String manual = 'MANUAL';
  static const String other = 'OTHER';
}

/// Mirrors `CropCycleRead` in
/// `backend/api/app/modules/crop_cycles/schemas.py` field-for-field.
class CropCycle {
  final String id;
  final String fieldId;
  final String cropCode;
  final String? variety;
  final DateTime? plantingDate;
  final DateTime? expectedHarvestDate;
  final DateTime? actualHarvestDate;
  final String? currentStage;
  final String? irrigationType;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const CropCycle({
    required this.id,
    required this.fieldId,
    required this.cropCode,
    this.variety,
    this.plantingDate,
    this.expectedHarvestDate,
    this.actualHarvestDate,
    this.currentStage,
    this.irrigationType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory CropCycle.fromJson(Map<String, dynamic> json) {
    return CropCycle(
      id: json['id'] as String,
      fieldId: json['field_id'] as String,
      cropCode: json['crop_code'] as String,
      variety: json['variety'] as String?,
      plantingDate: _parseDate(json['planting_date']),
      expectedHarvestDate: _parseDate(json['expected_harvest_date']),
      actualHarvestDate: _parseDate(json['actual_harvest_date']),
      currentStage: json['current_stage'] as String?,
      irrigationType: json['irrigation_type'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String? _formatDateOrNull(DateTime? date) =>
      date == null ? null : _formatDate(date);

  /// Body for `POST /api/v1/fields/{fieldId}/crop-cycles`
  /// (`CropCycleCreate`).
  static Map<String, dynamic> toCreateJson({
    required String cropCode,
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? currentStage,
    String? irrigationType,
    String status = CropCycleStatus.planned,
  }) {
    return {
      'crop_code': cropCode,
      'variety': ?variety,
      'planting_date': ?_formatDateOrNull(plantingDate),
      'expected_harvest_date': ?_formatDateOrNull(expectedHarvestDate),
      'current_stage': ?currentStage,
      'irrigation_type': ?irrigationType,
      'status': status,
    };
  }

  /// Body for `PATCH /api/v1/crop-cycles/{id}` (`CropCycleUpdate`).
  static Map<String, dynamic> toUpdateJson({
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    DateTime? actualHarvestDate,
    String? currentStage,
    String? irrigationType,
    String? status,
    required int expectedVersion,
  }) {
    return {
      'variety': ?variety,
      'planting_date': ?_formatDateOrNull(plantingDate),
      'expected_harvest_date': ?_formatDateOrNull(expectedHarvestDate),
      'actual_harvest_date': ?_formatDateOrNull(actualHarvestDate),
      'current_stage': ?currentStage,
      'irrigation_type': ?irrigationType,
      'status': ?status,
      'expected_version': expectedVersion,
    };
  }
}
