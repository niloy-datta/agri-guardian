/// Typed mirrors of `backend/api/app/modules/rotation/schemas.py`.
///
/// Every value here comes from the FastAPI response; nothing is computed or
/// invented on the device. Provider credentials never reach Flutter.
library;

List<String> _strings(Object? v) =>
    (v as List? ?? const []).map((e) => '$e').toList(growable: false);

class RotationLocation {
  final double latitude;
  final double longitude;
  final bool inBangladesh;
  final String? district;
  final String? division;
  final bool nearBoundary;
  final String? bamisRegion;
  final List<String> calendarCrops;

  const RotationLocation({
    required this.latitude,
    required this.longitude,
    required this.inBangladesh,
    required this.district,
    required this.division,
    required this.nearBoundary,
    required this.bamisRegion,
    required this.calendarCrops,
  });

  factory RotationLocation.fromJson(Map<String, dynamic> j) => RotationLocation(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        inBangladesh: j['in_bangladesh'] as bool,
        district: j['district'] as String?,
        division: j['division'] as String?,
        nearBoundary: j['near_boundary'] as bool? ?? false,
        bamisRegion: j['bamis_region'] as String?,
        calendarCrops: _strings(j['calendar_crops']),
      );
}

class RotationClaim {
  final String text;
  final String source;
  final String uncertainty;

  const RotationClaim(this.text, this.source, this.uncertainty);

  factory RotationClaim.fromJson(Map<String, dynamic> j) => RotationClaim(
        j['text'] as String,
        j['source'] as String? ?? '',
        j['uncertainty'] as String? ?? '',
      );
}

class RotationScenario {
  final List<String> crops;
  final int overlapDays;
  final List<String> irrigationDependent;
  final List<String> unknownWaterNeed;
  final int riceSeasons;
  final bool hasPulse;
  final int? weakestGaezIndex;
  final List<RotationClaim> claims;

  const RotationScenario({
    required this.crops,
    required this.overlapDays,
    required this.irrigationDependent,
    required this.unknownWaterNeed,
    required this.riceSeasons,
    required this.hasPulse,
    required this.weakestGaezIndex,
    required this.claims,
  });

  factory RotationScenario.fromJson(Map<String, dynamic> j) => RotationScenario(
        crops: _strings(j['crops']),
        overlapDays: j['overlap_days'] as int,
        irrigationDependent: _strings(j['irrigation_dependent']),
        unknownWaterNeed: _strings(j['unknown_water_need']),
        riceSeasons: j['rice_seasons'] as int,
        hasPulse: j['has_pulse'] as bool,
        weakestGaezIndex: j['weakest_gaez_index'] as int?,
        claims: (j['claims'] as List)
            .map((c) => RotationClaim.fromJson(Map<String, dynamic>.from(c)))
            .toList(growable: false),
      );
}

class EvidenceSummary {
  final int dataset;
  final String name;
  final String status;
  final String resolution;
  final String sourceUrl;
  final String caveat;
  final String reason;

  const EvidenceSummary({
    required this.dataset,
    required this.name,
    required this.status,
    required this.resolution,
    required this.sourceUrl,
    required this.caveat,
    required this.reason,
  });

  bool get isAvailable => status == 'AVAILABLE';

  factory EvidenceSummary.fromJson(Map<String, dynamic> j) => EvidenceSummary(
        dataset: j['dataset'] as int,
        name: j['name'] as String,
        status: j['status'] as String,
        resolution: j['resolution'] as String? ?? '',
        sourceUrl: j['source_url'] as String? ?? '',
        caveat: j['caveat'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
      );
}

class RotationComparison {
  final bool insufficientEvidence;
  final RotationLocation location;
  final List<RotationScenario> scenarios;
  final List<({String crop, String reason})> excluded;
  final List<String> unsupportedPriorities;
  final List<String> reasons;
  final List<EvidenceSummary> evidence;
  final DateTime? retrievedAt;
  final String disclaimer;

  const RotationComparison({
    required this.insufficientEvidence,
    required this.location,
    required this.scenarios,
    required this.excluded,
    required this.unsupportedPriorities,
    required this.reasons,
    required this.evidence,
    required this.retrievedAt,
    required this.disclaimer,
  });

  /// Evidence older than this is shown as stale (the response is a snapshot).
  bool isStale(DateTime now, {Duration maxAge = const Duration(hours: 24)}) =>
      retrievedAt == null || now.difference(retrievedAt!) > maxAge;

  factory RotationComparison.fromJson(Map<String, dynamic> j) => RotationComparison(
        insufficientEvidence: j['status'] == 'INSUFFICIENT_EVIDENCE',
        location: RotationLocation.fromJson(Map<String, dynamic>.from(j['location'])),
        scenarios: (j['scenarios'] as List)
            .map((s) => RotationScenario.fromJson(Map<String, dynamic>.from(s)))
            .toList(growable: false),
        excluded: (j['excluded'] as List)
            .map((e) => (crop: '${e['crop']}', reason: '${e['reason']}'))
            .toList(growable: false),
        unsupportedPriorities: _strings(j['unsupported_priorities']),
        reasons: _strings(j['reasons']),
        evidence: (j['evidence'] as List)
            .map((e) => EvidenceSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        retrievedAt: DateTime.tryParse(j['retrieved_at'] as String? ?? ''),
        disclaimer: j['disclaimer'] as String? ?? '',
      );
}

class RotationProfile {
  final List<String> previousCrops;
  final String irrigationAccess; // none | supplementary | full
  final double? budgetBdt;
  final List<String> preferredOutcomes;
  final bool consentToPersonalise;

  const RotationProfile({
    this.previousCrops = const [],
    this.irrigationAccess = 'none',
    this.budgetBdt,
    this.preferredOutcomes = const [],
    this.consentToPersonalise = false,
  });

  RotationProfile copyWith({
    List<String>? previousCrops,
    String? irrigationAccess,
    double? budgetBdt,
    List<String>? preferredOutcomes,
    bool? consentToPersonalise,
  }) =>
      RotationProfile(
        previousCrops: previousCrops ?? this.previousCrops,
        irrigationAccess: irrigationAccess ?? this.irrigationAccess,
        budgetBdt: budgetBdt ?? this.budgetBdt,
        preferredOutcomes: preferredOutcomes ?? this.preferredOutcomes,
        consentToPersonalise: consentToPersonalise ?? this.consentToPersonalise,
      );

  Map<String, dynamic> toJson() => {
        'previous_crops': previousCrops,
        'irrigation_access': irrigationAccess,
        'budget_bdt': budgetBdt,
        'preferred_outcomes': preferredOutcomes,
        'consent_to_personalise': consentToPersonalise,
      };

  factory RotationProfile.fromJson(Map<String, dynamic> j) => RotationProfile(
        previousCrops: _strings(j['previous_crops']),
        irrigationAccess: j['irrigation_access'] as String? ?? 'none',
        budgetBdt: double.tryParse('${j['budget_bdt'] ?? ''}'),
        preferredOutcomes: _strings(j['preferred_outcomes']),
        consentToPersonalise: j['consent_to_personalise'] as bool? ?? false,
      );
}
