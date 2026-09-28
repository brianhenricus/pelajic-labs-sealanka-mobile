import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/home/domain/entities/fishing_condition.dart';
import 'package:sea_lanka/features/home/domain/entities/weather_summary.dart';

abstract class HomeRepository {
  Future<Either<Failure, WeatherSummary>> getWeatherSummary(
      {required double lat, required double lon});

  Future<Either<Failure, FishingCondition>> getFishingCondition(
      {required double lat, required double lon});
}
