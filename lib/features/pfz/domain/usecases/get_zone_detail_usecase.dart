import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';
import 'package:sea_lanka/features/pfz/domain/repositories/pfz_repository.dart';

class GetZoneDetailUseCase {
  final PfzRepository repository;
  GetZoneDetailUseCase(this.repository);

  Future<Either<Failure, PfzPick>> call(String pickId) =>
      repository.getPickDetail(pickId);
}
