import 'package:sea_lanka/features/marine_traffic/domain/entities/vessel.dart';

class FishingEffortCellModel extends FishingEffortCell {
  const FishingEffortCellModel({
    required super.date,
    required super.flag,
    required super.lat,
    required super.lon,
    required super.fishingHours,
    required super.vesselCount,
  });

  factory FishingEffortCellModel.fromJson(Map<String, dynamic> json) =>
      FishingEffortCellModel(
        date: json['date'] as String,
        flag: json['flag'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        fishingHours: (json['fishing_hours'] as num).toDouble(),
        vesselCount: json['vessel_count'] as int,
      );
}

class VesselsSnapshotModel extends VesselsSnapshot {
  const VesselsSnapshotModel({
    required super.cells,
    required super.asOf,
    required super.attribution,
  });

  factory VesselsSnapshotModel.fromJson(Map<String, dynamic> json) =>
      VesselsSnapshotModel(
        cells: (json['vessels'] as List<dynamic>)
            .map((e) => FishingEffortCellModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        asOf: json['as_of'] != null ? DateTime.parse(json['as_of'] as String) : null,
        attribution: json['attribution'] as String,
      );
}
