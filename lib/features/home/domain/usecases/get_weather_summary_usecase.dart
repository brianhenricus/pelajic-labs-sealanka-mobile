import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/home/domain/entities/weather_summary.dart';
import 'package:sea_lanka/features/home/domain/repositories/home_repository.dart';

class GetWeatherSummaryUseCase {
  final HomeRepository repository;
  GetWeatherSummaryUseCase(this.repository);

  Future<Either<Failure, WeatherSummary>> call(LocationParams params) =>
      repository.getWeatherSummary(lat: params.lat, lon: params.lon);
}

class LocationParams extends Equatable {
  final double lat;
  final double lon;
  const LocationParams({required this.lat, required this.lon});

  @override
  List<Object> get props => [lat, lon];
}
