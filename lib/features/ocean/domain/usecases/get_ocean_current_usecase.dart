import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/ocean/domain/entities/ocean_current.dart';
import 'package:sea_lanka/features/ocean/domain/repositories/ocean_repository.dart';

class GetOceanCurrentUseCase {
  final OceanRepository repository;
  GetOceanCurrentUseCase(this.repository);

  Future<Either<Failure, OceanCurrent>> call({required double lat, required double lon}) =>
      repository.getCurrent(lat: lat, lon: lon);
}
