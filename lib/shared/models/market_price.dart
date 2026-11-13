class MarketPrice {
  final String commodity;
  final double pricePerMaund;
  final double changePercentage7d;
  final String marketName;

  const MarketPrice({
    required this.commodity,
    required this.pricePerMaund,
    required this.changePercentage7d,
    required this.marketName,
  });
}
