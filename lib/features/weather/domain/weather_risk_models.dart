/// Presentation contract for the Weather Risk Center.
///
/// The backend does not yet expose a current-conditions / forecast
/// endpoint (only `/advisory/planting-window` and the Rajshahi pilot,
/// which are historical NASA POWER climatology, not a forecast). This
/// contract is what a future FastAPI weather-risk endpoint must fill;
/// until then every snapshot carries its honest [WeatherDataOrigin] so
/// the UI never presents sample numbers as live data.
library;

import '../../../core/localization/localized_text.dart';

/// Where a snapshot's values actually came from.
enum WeatherDataOrigin {
  /// Fetched from the backend on this request.
  live,

  /// A previously fetched backend response served from local storage.
  cached,

  /// Hand-written sample values for UI demonstration only - not
  /// observations, not a forecast, not derived from any provider.
  demo,
}

enum WeatherRiskLevel { low, moderate, high, severe }

enum WeatherConditionKind { sunny, partlyCloudy, cloudy, rain, thunderstorm }

enum IrrigationAction { irrigate, reduce, skip }

enum WeatherHazardKind { rainfall, heat, wind }

enum EvidenceSourceStatus { connected, unavailable, demo }

class CurrentConditions {
  final double temperatureC;
  final double feelsLikeC;
  final int humidityPercent;
  final double windSpeedKmH;
  final WeatherConditionKind condition;
  final LocalizedText conditionLabel;

  const CurrentConditions({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.windSpeedKmH,
    required this.condition,
    required this.conditionLabel,
  });
}

class RainfallOutlook {
  /// Probability of measurable rain in the next 24 hours, 0-100.
  final int probabilityPercent24h;
  final double expectedMm24h;
  final WeatherRiskLevel risk;

  const RainfallOutlook({
    required this.probabilityPercent24h,
    required this.expectedMm24h,
    required this.risk,
  });
}

/// One entry of the risk strip (rainfall / heat stress / storm-wind).
class HazardRisk {
  final WeatherHazardKind kind;
  final WeatherRiskLevel level;
  final LocalizedText detail;

  const HazardRisk({
    required this.kind,
    required this.level,
    required this.detail,
  });
}

class DailyForecast {
  final DateTime date;
  final WeatherConditionKind condition;
  final double minTempC;
  final double maxTempC;
  final int rainProbabilityPercent;
  final WeatherRiskLevel risk;

  const DailyForecast({
    required this.date,
    required this.condition,
    required this.minTempC,
    required this.maxTempC,
    required this.rainProbabilityPercent,
    required this.risk,
  });
}

class IrrigationDecision {
  final IrrigationAction action;
  final LocalizedText headline;
  final LocalizedText reason;

  const IrrigationDecision({
    required this.action,
    required this.headline,
    required this.reason,
  });
}

class WeatherRiskAlert {
  final WeatherRiskLevel level;
  final LocalizedText title;
  final LocalizedText detail;
  final LocalizedText window;

  const WeatherRiskAlert({
    required this.level,
    required this.title,
    required this.detail,
    required this.window,
  });
}

class EvidenceSource {
  final LocalizedText name;
  final LocalizedText description;
  final EvidenceSourceStatus status;

  const EvidenceSource({
    required this.name,
    required this.description,
    required this.status,
  });
}

class WeatherRiskSnapshot {
  final WeatherDataOrigin origin;

  /// Field / location context shown on the hero card.
  final LocalizedText fieldLabel;

  /// When the underlying values were retrieved (or cached). Always null
  /// for demo data, which was never retrieved from anywhere.
  final DateTime? retrievedAt;

  final CurrentConditions current;
  final RainfallOutlook rainfall;
  final List<HazardRisk> hazards;
  final List<DailyForecast> forecast;
  final IrrigationDecision irrigation;

  /// Null when there is no active extreme-weather warning.
  final WeatherRiskAlert? alert;
  final List<EvidenceSource> sources;

  const WeatherRiskSnapshot({
    required this.origin,
    required this.fieldLabel,
    required this.retrievedAt,
    required this.current,
    required this.rainfall,
    required this.hazards,
    required this.forecast,
    required this.irrigation,
    required this.alert,
    required this.sources,
  });
}
