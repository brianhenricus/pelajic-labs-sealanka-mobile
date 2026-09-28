import 'package:equatable/equatable.dart';

enum FishingConditionLevel { excellent, good, fair, poor }

class FishingCondition extends Equatable {
  final FishingConditionLevel level;
  final int score;
  final String description;
  final List<String> tips;

  const FishingCondition({
    required this.level,
    required this.score,
    required this.description,
    required this.tips,
  });

  @override
  List<Object> get props => [level, score, description, tips];
}
