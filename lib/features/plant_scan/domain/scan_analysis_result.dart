/// Evidence state for an image-based plant scan.
///
/// A prediction is only available when a validated inference service returns
/// one. The app must not turn an unavailable analysis into a disease record.
enum IntelligenceDataStatus {
  live,
  cached,
  demo,
  stale,
  unavailable,
  insufficientEvidence,
}

class ScanAnalysisResult {
  final IntelligenceDataStatus status;
  final String? diseaseName;
  final double? confidence;
  final String source;
  final DateTime checkedAt;
  final String limitation;

  const ScanAnalysisResult({
    required this.status,
    required this.diseaseName,
    required this.confidence,
    required this.source,
    required this.checkedAt,
    required this.limitation,
  });

  factory ScanAnalysisResult.unavailable({required DateTime checkedAt}) {
    return ScanAnalysisResult(
      status: IntelligenceDataStatus.unavailable,
      diseaseName: null,
      confidence: null,
      source: 'Plant disease inference service',
      checkedAt: checkedAt,
      limitation: 'Image analysis is not connected. No diagnosis was produced or saved.',
    );
  }
}
