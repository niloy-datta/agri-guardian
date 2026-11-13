/// Models for Land Digital Twin, NASA/Sentinel Satellite Evidence, and Bangladesh Market Data
library;

class LandParcel {
  final String id;
  final String name;
  final String crop;
  final double areaAcres;
  final double healthScore;
  final String statusLevel; // normal, warning, critical
  final String district;
  final String upazila;
  final SatelliteTelemetry telemetry;

  const LandParcel({
    required this.id,
    required this.name,
    required this.crop,
    required this.areaAcres,
    required this.healthScore,
    required this.statusLevel,
    required this.district,
    required this.upazila,
    required this.telemetry,
  });

  factory LandParcel.sampleBoroField() {
    return const LandParcel(
      id: 'field_01',
      name: 'উত্তরের বোরো জমি',
      crop: 'ধান (ব্রি ধান-২৮)',
      areaAcres: 1.45,
      healthScore: 84.0,
      statusLevel: 'warning',
      district: 'ময়মনসিংহ',
      upazila: 'ত্রিশাল',
      telemetry: SatelliteTelemetry(
        gpmRainfallMm24h: 38.5,
        hlsNdviScore: 0.74,
        hlsNdwiWaterIndex: 0.32,
        sentinel1RadarSoilMoisture: 'উচ্চ জলমগ্নতা (Waterlogged)',
        nasademElevationMeters: 14.2,
        anomalyZone: 'উত্তর-পূর্ব পাশে পানি জমা',
        lastPassTime: '৪ ঘণ্টা আগে',
      ),
    );
  }
}

class SatelliteTelemetry {
  /// NASA GPM/IMERG near-real-time precipitation (latency ~4h)
  final double gpmRainfallMm24h;

  /// HLS Landsat + Sentinel-2 (30m resolution, 2-3 day repeat)
  final double hlsNdviScore;
  final double hlsNdwiWaterIndex;

  /// Sentinel-1 SAR Radar (cloud-penetrating soil moisture)
  final String sentinel1RadarSoilMoisture;

  /// NASADEM (30m elevation for drainage/depression analysis)
  final double nasademElevationMeters;

  final String anomalyZone;
  final String lastPassTime;

  const SatelliteTelemetry({
    required this.gpmRainfallMm24h,
    required this.hlsNdviScore,
    required this.hlsNdwiWaterIndex,
    required this.sentinel1RadarSoilMoisture,
    required this.nasademElevationMeters,
    required this.anomalyZone,
    required this.lastPassTime,
  });
}

class MarketPriceItem {
  final String commodityBn;
  final String unit;
  final double wholesalePrice;
  final double retailPrice;
  final double priceTrend7dPercent;
  final String recommendation; // 'আজ বিক্রি করুন' or 'অপেক্ষা করুন'

  const MarketPriceItem({
    required this.commodityBn,
    required this.unit,
    required this.wholesalePrice,
    required this.retailPrice,
    required this.priceTrend7dPercent,
    required this.recommendation,
  });
}
