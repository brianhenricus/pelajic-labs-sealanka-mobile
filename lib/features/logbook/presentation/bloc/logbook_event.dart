part of 'logbook_bloc.dart';

abstract class LogbookEvent extends Equatable {
  const LogbookEvent();
  @override
  List<Object?> get props => [];
}

class TripsRequested extends LogbookEvent {
  const TripsRequested();
}

class TripSubmitted extends LogbookEvent {
  final CreateTripParams params;
  const TripSubmitted(this.params);

  @override
  List<Object?> get props => [params];
}
