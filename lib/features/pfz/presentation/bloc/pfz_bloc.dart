import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';
import 'package:sea_lanka/features/pfz/domain/usecases/get_zone_detail_usecase.dart';
import 'package:sea_lanka/features/pfz/domain/usecases/get_zones_for_date_usecase.dart';

part 'pfz_event.dart';
part 'pfz_state.dart';

class PfzBloc extends Bloc<PfzEvent, PfzState> {
  final GetZonesForDateUseCase getZonesForDate;
  final GetZoneDetailUseCase getZoneDetail;

  PfzBloc({
    required this.getZonesForDate,
    required this.getZoneDetail,
  }) : super(PfzInitial()) {
    on<PfzZonesRequested>(_onZonesRequested);
    on<PfzZoneDetailRequested>(_onZoneDetailRequested);
  }

  Future<void> _onZonesRequested(
      PfzZonesRequested event, Emitter<PfzState> emit) async {
    emit(PfzLoading());
    final result = await getZonesForDate(event.date, species: event.species);
    result.fold(
      (failure) => emit(PfzError(failure.message)),
      // An empty list is a valid, expected result (nothing passed the
      // model's safety gates that day) -- not folded into PfzError.
      (zones) => emit(PfzZonesLoaded(zones: zones, selectedDate: event.date)),
    );
  }

  Future<void> _onZoneDetailRequested(
      PfzZoneDetailRequested event, Emitter<PfzState> emit) async {
    final result = await getZoneDetail(event.zoneId);
    result.fold(
      (failure) => emit(PfzError(failure.message)),
      (zone) {
        if (state is PfzZonesLoaded) {
          emit((state as PfzZonesLoaded).copyWith(selectedZone: zone));
        }
      },
    );
  }
}
