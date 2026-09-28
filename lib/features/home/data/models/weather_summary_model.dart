import 'package:sea_lanka/features/home/domain/entities/weather_summary.dart';

class WeatherSummaryModel extends WeatherSummary {
  const WeatherSummaryModel({
    required super.windSpeedKnots,
    required super.windDirectionDeg,
    required super.waveHeightM,
    required super.seaTempC,
    required super.visibilityKm,
    required super.pressureHpa,
    required super.rainChancePercent,
    super.weatherCode,
    super.cloudCoverPercent,
    required super.highTideLabel,
    required super.condition,
    required super.updatedAt,
  });

  factory WeatherSummaryModel.fromJson(Map<String, dynamic> json) =>
      WeatherSummaryModel(
        windSpeedKnots: (json['wind_speed_knots'] as num).toDouble(),
        windDirectionDeg: (json['wind_direction_deg'] as num).toDouble(),
        waveHeightM: (json['wave_height_m'] as num?)?.toDouble(),
        seaTempC: (json['sea_temp_c'] as num?)?.toDouble(),
        visibilityKm: (json['visibility_km'] as num?)?.toDouble(),
        pressureHpa: (json['pressure_hpa'] as num?)?.toDouble(),
        rainChancePercent: (json['rain_chance_percent'] as num?)?.toDouble(),
        weatherCode: json['weather_code'] as int?,
        cloudCoverPercent: (json['cloud_cover_percent'] as num?)?.toDouble(),
        highTideLabel: json['high_tide_label'] as String?,
        condition: json['condition'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
