part of 'ocean_bloc.dart';

abstract class OceanEvent extends Equatable {
  const OceanEvent();
  @override
  List<Object?> get props => [];
}

class OceanRequested extends OceanEvent {
  final double lat;
  final double lon;
  const OceanRequested({required this.lat, required this.lon});

  @override
  List<Object> get props => [lat, lon];
}
