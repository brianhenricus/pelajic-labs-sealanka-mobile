import 'package:equatable/equatable.dart';

class WeatherSummary extends Equatable {
  final double windSpeedKnots;
  final double windDirectionDeg;
  // Nullable: backend doesn't have a wave/sea-temp/visibility/pressure/rain
  // source wired up yet (architecture doc §4 only covers wind, currents,
  // SST, solunar, tides) — these come back null from the real API, not a
  // missing-data edge case to guard against defensively.
  final double? waveHeightM;
  final double? seaTempC;
  final double? visibilityKm;
  final double? pressureHpa;
  final double? rainChancePercent;
  // Real Open-Meteo sky-condition signal (WMO weather code + total cloud
  // cover %) -- see sealanka-be's wind_service.get_wind_at_point docstring
  // for why this exists alongside rainChancePercent instead of relying on
  // that alone (a light drizzle-level precip rate was crossing the old
  // rain-chance threshold and showing full "raining" visuals on an
  // actually-just-overcast day). Null against an older backend.
  final int? weatherCode;
  final double? cloudCoverPercent;
  final String? highTideLabel;
  final String condition;
  final DateTime updatedAt;

  const WeatherSummary({
    required this.windSpeedKnots,
    required this.windDirectionDeg,
    required this.waveHeightM,
    required this.seaTempC,
    required this.visibilityKm,
    required this.pressureHpa,
    required this.rainChancePercent,
    this.weatherCode,
    this.cloudCoverPercent,
    required this.highTideLabel,
    required this.condition,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        windSpeedKnots,
        windDirectionDeg,
        waveHeightM,
        seaTempC,
        visibilityKm,
        pressureHpa,
        rainChancePercent,
        weatherCode,
        cloudCoverPercent,
        highTideLabel,
        condition,
        updatedAt,
      ];
}
