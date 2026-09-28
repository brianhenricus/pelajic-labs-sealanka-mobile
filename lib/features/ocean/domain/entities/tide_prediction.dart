import 'package:equatable/equatable.dart';

class TidePrediction extends Equatable {
  final DateTime time;
  final double heightM;
  final bool isHighTide;

  const TidePrediction({
    required this.time,
    required this.heightM,
    required this.isHighTide,
  });

  @override
  List<Object> get props => [time, heightM, isHighTide];
}
