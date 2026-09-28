import 'package:sea_lanka/features/ocean/domain/entities/ocean_current.dart';

class OceanCurrentModel extends OceanCurrent {
  const OceanCurrentModel({
    required super.speedKnots,
    required super.directionDeg,
    required super.seaSurfaceTempC,
    required super.salinityPpt,
    required super.updatedAt,
  });

  factory OceanCurrentModel.fromJson(Map<String, dynamic> json) =>
      OceanCurrentModel(
        speedKnots: (json['speed_knots'] as num).toDouble(),
        directionDeg: (json['direction_deg'] as num).toDouble(),
        seaSurfaceTempC: (json['sea_surface_temp_c'] as num?)?.toDouble(),
        salinityPpt: (json['salinity_ppt'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
