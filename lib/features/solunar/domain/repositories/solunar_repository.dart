import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_snapshot.dart';

abstract class SolunarRepository {
  Future<Either<Failure, SolunarSnapshot>> getSolunar(
      {required double lat, required double lon, DateTime? date});
}
