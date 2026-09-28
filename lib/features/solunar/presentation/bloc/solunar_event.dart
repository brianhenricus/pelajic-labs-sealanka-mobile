part of 'solunar_bloc.dart';

abstract class SolunarEvent extends Equatable {
  const SolunarEvent();
  @override
  List<Object?> get props => [];
}

class SolunarRequested extends SolunarEvent {
  final double lat;
  final double lon;
  const SolunarRequested({required this.lat, required this.lon});

  @override
  List<Object> get props => [lat, lon];
}
