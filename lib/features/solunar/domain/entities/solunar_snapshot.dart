import 'package:equatable/equatable.dart';
import 'package:sea_lanka/features/solunar/domain/entities/lunar_data.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solar_data.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_period.dart';

class SolunarSnapshot extends Equatable {
  final SolarData solar;
  final LunarData lunar;
  final List<SolunarPeriod> periods;
  // activityRating (poor/fair/good/excellent) and activityScore (0-100) are
  // two genuinely different pieces of information from the backend, not
  // just two names for the same value -- both kept.
  final String activityRating;
  final int activityScore;

  const SolunarSnapshot({
    required this.solar,
    required this.lunar,
    required this.periods,
    required this.activityRating,
    required this.activityScore,
  });

  @override
  List<Object?> get props =>
      [solar, lunar, periods, activityRating, activityScore];
}
