part of 'vessels_bloc.dart';

abstract class VesselsState extends Equatable {
  const VesselsState();
  @override
  List<Object?> get props => [];
}

class VesselsInitial extends VesselsState {}

class VesselsLoading extends VesselsState {}

class VesselsLoaded extends VesselsState {
  final VesselsSnapshot snapshot;
  const VesselsLoaded(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}

class VesselsError extends VesselsState {
  final String message;
  const VesselsError(this.message);

  @override
  List<Object?> get props => [message];
}
