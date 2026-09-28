import 'package:equatable/equatable.dart';

class LunarData extends Equatable {
  final String phase;
  final double illuminationPercent;
  final DateTime moonrise;
  final DateTime moonset;

  const LunarData({
    required this.phase,
    required this.illuminationPercent,
    required this.moonrise,
    required this.moonset,
  });

  @override
  List<Object> get props => [phase, illuminationPercent, moonrise, moonset];
}
