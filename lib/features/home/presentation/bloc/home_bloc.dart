import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/home/domain/entities/fishing_condition.dart';
import 'package:sea_lanka/features/home/domain/entities/weather_summary.dart';
import 'package:sea_lanka/features/home/domain/usecases/get_fishing_condition_usecase.dart';
import 'package:sea_lanka/features/home/domain/usecases/get_weather_summary_usecase.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetWeatherSummaryUseCase getWeatherSummary;
  final GetFishingConditionUseCase getFishingCondition;

  HomeBloc({
    required this.getWeatherSummary,
    required this.getFishingCondition,
  }) : super(HomeInitial()) {
    on<HomeDataRequested>(_onDataRequested);
  }

  Future<void> _onDataRequested(
      HomeDataRequested event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    final params = LocationParams(lat: event.lat, lon: event.lon);
    final weatherResult = await getWeatherSummary(params);
    final conditionResult = await getFishingCondition(params);

    weatherResult.fold(
      (failure) => emit(HomeError(failure.message)),
      (weather) {
        conditionResult.fold(
          (failure) => emit(HomeError(failure.message)),
          (condition) =>
              emit(HomeLoaded(weather: weather, condition: condition)),
        );
      },
    );
  }
}
