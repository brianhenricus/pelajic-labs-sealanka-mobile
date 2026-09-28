part of 'wind_bloc.dart';

abstract class WindEvent extends Equatable {
  const WindEvent();
  @override
  List<Object?> get props => [];
}

class WindRequested extends WindEvent {
  final double lat;
  final double lon;
  const WindRequested({required this.lat, required this.lon});

  @override
  List<Object> get props => [lat, lon];
}
