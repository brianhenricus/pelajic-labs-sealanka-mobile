import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/ocean/domain/entities/ocean_current.dart';
import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';
import 'package:sea_lanka/features/ocean/domain/usecases/get_ocean_current_usecase.dart';
import 'package:sea_lanka/features/ocean/domain/usecases/get_tides_usecase.dart';

part 'ocean_event.dart';
part 'ocean_state.dart';

class OceanBloc extends Bloc<OceanEvent, OceanState> {
  final GetOceanCurrentUseCase getCurrent;
  final GetTidesUseCase getTides;

  OceanBloc({
    required this.getCurrent,
    required this.getTides,
  }) : super(OceanInitial()) {
    on<OceanRequested>(_on);
  }

  Future<void> _on(OceanRequested event, Emitter<OceanState> emit) async {
    emit(OceanLoading());
    final currentResult = await getCurrent(lat: event.lat, lon: event.lon);
    final tidesResult = await getTides(lat: event.lat, lon: event.lon);

    currentResult.fold(
      (failure) => emit(OceanError(failure.message)),
      (current) {
        // Tide predictions only exist near the 16 coastal reference
        // stations (see sealanka-be's tide_reference_points) -- a point
        // out in open water, e.g. from tapping the nullschool-style
        // current map, legitimately has none nearby. That's not an error
        // blocking the whole screen, just "no tide data here" -- same as
        // any other out-of-range point, so it degrades to an empty list
        // rather than suppressing the current reading that DID succeed.
        final tides = tidesResult.fold((_) => <TidePrediction>[], (t) => t);
        emit(OceanLoaded(current: current, tides: tides));
      },
    );
  }
}
