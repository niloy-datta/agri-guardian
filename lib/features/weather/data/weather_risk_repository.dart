import '../../../core/localization/localized_text.dart';
import '../../../shared/demo/showcase_story.dart';
import '../domain/weather_risk_models.dart';

/// Source of [WeatherRiskSnapshot]s for the Weather Risk Center.
///
/// A future implementation backed by a FastAPI weather-risk endpoint
/// (NASA/Copernicus and other providers stay backend-only) returns
/// [WeatherDataOrigin.live] or [WeatherDataOrigin.cached]. No such
/// endpoint exists yet, so [DemoWeatherRiskRepository] is the only
/// implementation in this phase.
abstract interface class WeatherRiskRepository {
  Future<WeatherRiskSnapshot> fetchSnapshot();
}

/// Deterministic, hand-written sample values for demonstrating the UI.
///
/// Nothing here is observed, forecast, or derived from any provider:
/// every snapshot is [WeatherDataOrigin.demo] with no retrieval
/// timestamp, and every real provider is listed as unavailable. Only the
/// forecast *dates* follow the injected clock so the 7-day strip starts
/// today; the values themselves never change.
class DemoWeatherRiskRepository implements WeatherRiskRepository {
  final DateTime Function() _now;

  DemoWeatherRiskRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _days = <(WeatherConditionKind, double, double, int, WeatherRiskLevel)>[
    (WeatherConditionKind.partlyCloudy, 25, 32, 40, WeatherRiskLevel.moderate),
    (WeatherConditionKind.rain, 24, 30, 70, WeatherRiskLevel.high),
    (WeatherConditionKind.thunderstorm, 24, 29, 85, WeatherRiskLevel.severe),
    (WeatherConditionKind.rain, 24, 30, 60, WeatherRiskLevel.moderate),
    (WeatherConditionKind.cloudy, 25, 31, 30, WeatherRiskLevel.low),
    (WeatherConditionKind.partlyCloudy, 25, 33, 20, WeatherRiskLevel.low),
    (WeatherConditionKind.sunny, 26, 34, 10, WeatherRiskLevel.moderate),
  ];

  @override
  Future<WeatherRiskSnapshot> fetchSnapshot() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);

    return WeatherRiskSnapshot(
      origin: WeatherDataOrigin.demo,
      fieldLabel: LocalizedText(
        '${DemoStory.fieldCropBn} · ${DemoStory.location.districtBn}',
        '${DemoStory.fieldCropEn} · ${DemoStory.location.districtEn}',
      ),
      retrievedAt: null,
      // Shared with Home's weather pills so the two never disagree.
      current: CurrentConditions(
        temperatureC: DemoStory.weatherNow.temperatureC,
        feelsLikeC: 36,
        humidityPercent: DemoStory.weatherNow.humidityPercent,
        windSpeedKmH: 14,
        condition: WeatherConditionKind.partlyCloudy,
        conditionLabel: LocalizedText(
          DemoStory.weatherNow.conditionBn,
          DemoStory.weatherNow.conditionEn,
        ),
      ),
      rainfall: const RainfallOutlook(
        probabilityPercent24h: 70,
        expectedMm24h: 18,
        risk: WeatherRiskLevel.high,
      ),
      hazards: const [
        HazardRisk(
          kind: WeatherHazardKind.rainfall,
          level: WeatherRiskLevel.high,
          detail: LocalizedText('২৪ ঘণ্টায় ~১৮ মিমি', '~18 mm in 24 hours'),
        ),
        HazardRisk(
          kind: WeatherHazardKind.heat,
          level: WeatherRiskLevel.moderate,
          detail: LocalizedText('অনুভূত ৩৬°', 'Feels like 36°'),
        ),
        HazardRisk(
          kind: WeatherHazardKind.wind,
          level: WeatherRiskLevel.low,
          detail: LocalizedText('১৪ কিমি/ঘণ্টা', '14 km/h'),
        ),
      ],
      forecast: [
        for (var i = 0; i < _days.length; i++)
          DailyForecast(
            date: today.add(Duration(days: i)),
            condition: _days[i].$1,
            minTempC: _days[i].$2,
            maxTempC: _days[i].$3,
            rainProbabilityPercent: _days[i].$4,
            risk: _days[i].$5,
          ),
      ],
      irrigation: const IrrigationDecision(
        action: IrrigationAction.skip,
        headline: LocalizedText(
          'আজ সেচ স্থগিত রাখুন',
          'Hold irrigation today',
        ),
        reason: LocalizedText(
          'নমুনা পূর্বাভাসে আগামী ২৪ ঘণ্টায় বৃষ্টির সম্ভাবনা বেশি দেখানো '
              'হয়েছে। জমির পানি নিষ্কাশনের নালা খোলা রাখুন।',
          'The sample forecast shows a high chance of rain in the next 24 hours. '
              'Keep the field drainage channels open.',
        ),
      ),
      alert: const WeatherRiskAlert(
        level: WeatherRiskLevel.severe,
        title: LocalizedText('বজ্রঝড়ের সতর্কতা', 'Thunderstorm warning'),
        detail: LocalizedText(
          'নমুনা পূর্বাভাসে ভারী বৃষ্টি ও দমকা হাওয়া দেখানো হয়েছে। '
              'কীটনাশক বা সার প্রয়োগ পিছিয়ে দিন।',
          'The sample forecast shows heavy rain and gusty winds. '
              'Postpone pesticide or fertilizer application.',
        ),
        window: LocalizedText(
          'পরশু · বিকেল থেকে রাত',
          'Day after tomorrow · afternoon to night',
        ),
      ),
      sources: const [
        EvidenceSource(
          name: LocalizedText('Mukti ডেমো নমুনা', 'Mukti demo sample'),
          description: LocalizedText(
            'প্রদর্শনের জন্য হাতে লেখা নির্দিষ্ট মান',
            'Fixed hand-written values for display',
          ),
          status: EvidenceSourceStatus.demo,
        ),
        EvidenceSource(
          name: LocalizedText(
            'আবহাওয়া পূর্বাভাস এন্ডপয়েন্ট',
            'Weather forecast endpoint',
          ),
          description: LocalizedText(
            'Mukti ব্যাকএন্ডে এখনো তৈরি হয়নি',
            'Not yet built in the Mukti backend',
          ),
          status: EvidenceSourceStatus.unavailable,
        ),
        EvidenceSource(
          name: LocalizedText(
            'স্যাটেলাইট বৃষ্টিপাত ডেটা',
            'Satellite rainfall data',
          ),
          description: LocalizedText(
            'পরিকল্পিত উৎস — অ্যাপে এখনো সংযুক্ত নয়',
            'Planned source — not connected to the app yet',
          ),
          status: EvidenceSourceStatus.unavailable,
        ),
      ],
    );
  }
}
