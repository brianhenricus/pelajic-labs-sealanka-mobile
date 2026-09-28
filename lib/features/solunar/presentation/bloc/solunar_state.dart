part of 'solunar_bloc.dart';

abstract class SolunarState extends Equatable {
  const SolunarState();
  @override
  List<Object?> get props => [];
}

class SolunarInitial extends SolunarState {}

class SolunarLoading extends SolunarState {}

class SolunarLoaded extends SolunarState {
  final SolunarSnapshot snapshot;
  const SolunarLoaded(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}

class SolunarError extends SolunarState {
  final String message;
  const SolunarError(this.message);

  @override
  List<Object?> get props => [message];
}
