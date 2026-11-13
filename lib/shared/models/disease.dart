class Disease {
  final String id;
  final String nameBn;
  final String nameEn;
  final String scientificName;
  final double confidence;
  final String severity;

  const Disease({
    required this.id,
    required this.nameBn,
    required this.nameEn,
    required this.scientificName,
    required this.confidence,
    required this.severity,
  });
}
