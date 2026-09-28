import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';
import 'package:sea_lanka/features/logbook/domain/usecases/create_trip_usecase.dart';
import 'package:sea_lanka/features/logbook/domain/usecases/get_trips_usecase.dart';

part 'logbook_event.dart';
part 'logbook_state.dart';

class LogbookBloc extends Bloc<LogbookEvent, LogbookState> {
  final GetTripsUseCase getTrips;
  final CreateTripUseCase? createTrip;

  LogbookBloc({required this.getTrips, this.createTrip})
      : super(LogbookInitial()) {
    on<TripsRequested>(_onTripsRequested);
    on<TripSubmitted>(_onTripSubmitted);
  }

  Future<void> _onTripsRequested(
      TripsRequested event, Emitter<LogbookState> emit) async {
    emit(LogbookLoading());
    final result = await getTrips();
    result.fold(
      (failure) => emit(LogbookError(failure.message)),
      (trips) => emit(LogbookLoaded(trips)),
    );
  }

  Future<void> _onTripSubmitted(
      TripSubmitted event, Emitter<LogbookState> emit) async {
    final useCase = createTrip;
    if (useCase == null) return;
    emit(TripSubmissionInProgress());
    final result = await useCase(event.params);
    result.fold(
      (failure) => emit(TripSubmissionFailure(failure.message)),
      (trip) => emit(TripSubmissionSuccess(trip)),
    );
  }
}
