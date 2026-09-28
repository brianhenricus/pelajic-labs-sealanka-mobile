import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/home/domain/entities/fishing_condition.dart';
import 'package:sea_lanka/features/home/domain/repositories/home_repository.dart';
import 'package:sea_lanka/features/home/domain/usecases/get_weather_summary_usecase.dart';

class GetFishingConditionUseCase {
  final HomeRepository repository;
  GetFishingConditionUseCase(this.repository);

  Future<Either<Failure, FishingCondition>> call(LocationParams params) =>
      repository.getFishingCondition(lat: params.lat, lon: params.lon);
}
