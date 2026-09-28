part of 'ocean_bloc.dart';

abstract class OceanState extends Equatable {
  const OceanState();
  @override
  List<Object?> get props => [];
}

class OceanInitial extends OceanState {}

class OceanLoading extends OceanState {}

class OceanLoaded extends OceanState {
  final OceanCurrent current;
  final List<TidePrediction> tides;

  const OceanLoaded({required this.current, required this.tides});

  @override
  List<Object?> get props => [current, tides];
}

class OceanError extends OceanState {
  final String message;
  const OceanError(this.message);

  @override
  List<Object?> get props => [message];
}
