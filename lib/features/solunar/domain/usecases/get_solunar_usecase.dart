import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_snapshot.dart';
import 'package:sea_lanka/features/solunar/domain/repositories/solunar_repository.dart';

class GetSolunarUseCase {
  final SolunarRepository repository;
  GetSolunarUseCase(this.repository);

  Future<Either<Failure, SolunarSnapshot>> call(
          {required double lat, required double lon, DateTime? date}) =>
      repository.getSolunar(lat: lat, lon: lon, date: date);
}
