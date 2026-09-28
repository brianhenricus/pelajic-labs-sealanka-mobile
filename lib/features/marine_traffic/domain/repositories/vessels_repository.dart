import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/marine_traffic/domain/entities/vessel.dart';

abstract class VesselsRepository {
  Future<Either<Failure, VesselsSnapshot>> getVessels({
    required double lat,
    required double lon,
    required double radiusKm,
  });
}
