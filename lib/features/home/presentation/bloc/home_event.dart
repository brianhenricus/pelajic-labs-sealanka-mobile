part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

class HomeDataRequested extends HomeEvent {
  final double lat;
  final double lon;
  const HomeDataRequested({required this.lat, required this.lon});

  @override
  List<Object> get props => [lat, lon];
}
