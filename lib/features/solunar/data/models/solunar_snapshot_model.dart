import 'package:sea_lanka/features/solunar/domain/entities/lunar_data.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solar_data.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_period.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_snapshot.dart';

class SolunarSnapshotModel extends SolunarSnapshot {
  const SolunarSnapshotModel({
    required super.solar,
    required super.lunar,
    required super.periods,
    required super.activityRating,
    required super.activityScore,
  });

  factory SolunarSnapshotModel.fromJson(Map<String, dynamic> json) {
    final solarJson = json['solar'] as Map<String, dynamic>;
    final lunarJson = json['lunar'] as Map<String, dynamic>;
    final periodsJson = json['periods'] as List<dynamic>;

    final solar = SolarData(
      sunrise: DateTime.parse(solarJson['sunrise'] as String),
      sunset: DateTime.parse(solarJson['sunset'] as String),
      solarNoon: DateTime.parse(solarJson['solar_noon'] as String),
      dayLength:
          Duration(minutes: (solarJson['day_length_minutes'] as num).toInt()),
    );

    final lunar = LunarData(
      phase: lunarJson['phase'] as String,
      illuminationPercent:
          (lunarJson['illumination_percent'] as num).toDouble(),
      moonrise: DateTime.parse(lunarJson['moonrise'] as String),
      moonset: DateTime.parse(lunarJson['moonset'] as String),
    );

    final periods = periodsJson
        .map((e) => e as Map<String, dynamic>)
        .map(
          (p) => SolunarPeriod(
            start: DateTime.parse(p['start'] as String),
            end: DateTime.parse(p['end'] as String),
            isMajor: p['is_major'] as bool,
            rating: (p['rating'] as num).toInt(),
          ),
        )
        .toList();

    return SolunarSnapshotModel(
      solar: solar,
      lunar: lunar,
      periods: periods,
      activityRating: json['activity_rating'] as String,
      activityScore: (json['activity_score'] as num).toInt(),
    );
  }
}
