import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';
import 'package:sea_lanka/features/ocean/domain/repositories/ocean_repository.dart';

class GetTidesUseCase {
  final OceanRepository repository;
  GetTidesUseCase(this.repository);

  Future<Either<Failure, List<TidePrediction>>> call({required double lat, required double lon}) =>
      repository.getTides(lat: lat, lon: lon);
}
