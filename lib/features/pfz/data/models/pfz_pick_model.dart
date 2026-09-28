import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';

class PfzPickModel extends PfzPick {
  const PfzPickModel({
    required super.id,
    required super.species,
    required super.day,
    required super.rank,
    required super.lat,
    required super.lon,
    required super.calibratedProbability,
    required super.distCoastKm,
    required super.historyCount,
    required super.longRange,
    required super.modelVersion,
  });

  factory PfzPickModel.fromJson(Map<String, dynamic> json) => PfzPickModel(
        id: json['id'] as String,
        species: json['species'] as String,
        day: DateTime.parse(json['day'] as String),
        rank: json['rank'] as int,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        calibratedProbability:
            (json['calibrated_probability'] as num).toDouble(),
        distCoastKm: (json['dist_coast_km'] as num).toDouble(),
        historyCount: json['history_count'] as int,
        longRange: json['long_range'] as bool,
        modelVersion: json['model_version'] as String,
      );
}
