import 'package:equatable/equatable.dart';

class WindData extends Equatable {
  final double speedKnots;
  final double directionDeg;
  final double gustKnots;
  final String condition;
  final DateTime updatedAt;

  const WindData({
    required this.speedKnots,
    required this.directionDeg,
    required this.gustKnots,
    required this.condition,
    required this.updatedAt,
  });

  @override
  List<Object> get props =>
      [speedKnots, directionDeg, gustKnots, condition, updatedAt];
}
