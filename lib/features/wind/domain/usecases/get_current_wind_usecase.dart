import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/wind/domain/entities/wind_data.dart';
import 'package:sea_lanka/features/wind/domain/repositories/wind_repository.dart';

class GetCurrentWindUseCase {
  final WindRepository repository;
  GetCurrentWindUseCase(this.repository);

  Future<Either<Failure, WindData>> call({required double lat, required double lon}) =>
      repository.getCurrentWind(lat: lat, lon: lon);
}
