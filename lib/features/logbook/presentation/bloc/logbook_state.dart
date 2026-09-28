part of 'logbook_bloc.dart';

abstract class LogbookState extends Equatable {
  const LogbookState();
  @override
  List<Object?> get props => [];
}

class LogbookInitial extends LogbookState {}

class LogbookLoading extends LogbookState {}

class LogbookLoaded extends LogbookState {
  final List<TripLog> trips;
  const LogbookLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class LogbookError extends LogbookState {
  final String message;
  const LogbookError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripSubmissionInProgress extends LogbookState {}

class TripSubmissionSuccess extends LogbookState {
  final TripLog trip;
  const TripSubmissionSuccess(this.trip);

  @override
  List<Object?> get props => [trip];
}

class TripSubmissionFailure extends LogbookState {
  final String message;
  const TripSubmissionFailure(this.message);

  @override
  List<Object?> get props => [message];
}
