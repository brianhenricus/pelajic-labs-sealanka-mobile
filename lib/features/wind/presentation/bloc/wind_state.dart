part of 'wind_bloc.dart';

abstract class WindState extends Equatable {
  const WindState();
  @override
  List<Object?> get props => [];
}

class WindInitial extends WindState {}

class WindLoading extends WindState {}

class WindLoaded extends WindState {
  final WindData wind;
  const WindLoaded(this.wind);

  @override
  List<Object?> get props => [wind];
}

class WindError extends WindState {
  final String message;
  const WindError(this.message);

  @override
  List<Object?> get props => [message];
}
