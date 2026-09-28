import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/marine_traffic/domain/entities/vessel.dart';
import 'package:sea_lanka/features/marine_traffic/domain/repositories/vessels_repository.dart';

class GetVesselsUseCase {
  final VesselsRepository repository;
  GetVesselsUseCase(this.repository);

  Future<Either<Failure, VesselsSnapshot>> call({
    required double lat,
    required double lon,
    required double radiusKm,
  }) =>
      repository.getVessels(lat: lat, lon: lon, radiusKm: radiusKm);
}
