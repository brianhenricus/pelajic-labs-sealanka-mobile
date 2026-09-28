import 'package:equatable/equatable.dart';

class SolarData extends Equatable {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime solarNoon;
  final Duration dayLength;

  const SolarData({
    required this.sunrise,
    required this.sunset,
    required this.solarNoon,
    required this.dayLength,
  });

  @override
  List<Object> get props => [sunrise, sunset, solarNoon, dayLength];
}
