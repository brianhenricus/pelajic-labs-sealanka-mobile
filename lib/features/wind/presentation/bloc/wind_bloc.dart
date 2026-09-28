import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/wind/domain/entities/wind_data.dart';
import 'package:sea_lanka/features/wind/domain/usecases/get_current_wind_usecase.dart';

part 'wind_event.dart';
part 'wind_state.dart';

class WindBloc extends Bloc<WindEvent, WindState> {
  final GetCurrentWindUseCase getCurrentWind;

  WindBloc({required this.getCurrentWind}) : super(WindInitial()) {
    on<WindRequested>(_on);
  }

  Future<void> _on(WindRequested event, Emitter<WindState> emit) async {
    emit(WindLoading());
    final result = await getCurrentWind(lat: event.lat, lon: event.lon);
    result.fold(
      (failure) => emit(WindError(failure.message)),
      (wind) => emit(WindLoaded(wind)),
    );
  }
}
