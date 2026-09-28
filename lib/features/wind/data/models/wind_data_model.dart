import 'package:sea_lanka/features/wind/domain/entities/wind_data.dart';

class WindDataModel extends WindData {
  const WindDataModel({
    required super.speedKnots,
    required super.directionDeg,
    required super.gustKnots,
    required super.condition,
    required super.updatedAt,
  });

  factory WindDataModel.fromJson(Map<String, dynamic> json) => WindDataModel(
        speedKnots: (json['speed_knots'] as num).toDouble(),
        directionDeg: (json['direction_deg'] as num).toDouble(),
        gustKnots: (json['gust_knots'] as num).toDouble(),
        condition: json['condition'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}
