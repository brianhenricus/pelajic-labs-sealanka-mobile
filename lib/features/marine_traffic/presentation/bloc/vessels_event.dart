part of 'vessels_bloc.dart';

abstract class VesselsEvent extends Equatable {
  const VesselsEvent();
  @override
  List<Object?> get props => [];
}

class VesselsRequested extends VesselsEvent {
  final double lat;
  final double lon;
  const VesselsRequested({required this.lat, required this.lon});

  @override
  List<Object> get props => [lat, lon];
}
