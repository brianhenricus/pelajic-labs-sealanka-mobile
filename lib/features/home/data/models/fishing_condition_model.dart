import 'package:sea_lanka/features/home/domain/entities/fishing_condition.dart';

class FishingConditionModel extends FishingCondition {
  const FishingConditionModel({
    required super.level,
    required super.score,
    required super.description,
    required super.tips,
  });

  factory FishingConditionModel.fromJson(Map<String, dynamic> json) =>
      FishingConditionModel(
        level: FishingConditionLevel.values.firstWhere(
          (e) => e.name == (json['level'] as String).toLowerCase(),
          orElse: () => FishingConditionLevel.fair,
        ),
        score: json['score'] as int,
        description: json['description'] as String,
        tips: (json['tips'] as List<dynamic>).cast<String>(),
      );
}
