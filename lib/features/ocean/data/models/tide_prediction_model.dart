import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';

class TidePredictionModel extends TidePrediction {
  const TidePredictionModel({
    required super.time,
    required super.heightM,
    required super.isHighTide,
  });

  factory TidePredictionModel.fromJson(Map<String, dynamic> json) =>
      TidePredictionModel(
        time: DateTime.parse(json['time'] as String),
        heightM: (json['height_m'] as num).toDouble(),
        isHighTide: json['is_high_tide'] as bool,
      );
}
