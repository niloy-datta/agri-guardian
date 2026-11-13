class Weather {
  final double temperatureC;
  final int humidityPercent;
  final double windSpeedKmH;
  final String condition;
  final double rainfallMm24h;

  const Weather({
    required this.temperatureC,
    required this.humidityPercent,
    required this.windSpeedKmH,
    required this.condition,
    required this.rainfallMm24h,
  });
}
