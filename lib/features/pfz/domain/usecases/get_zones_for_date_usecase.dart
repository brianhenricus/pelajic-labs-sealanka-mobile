import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';
import 'package:sea_lanka/features/pfz/domain/repositories/pfz_repository.dart';

class GetZonesForDateUseCase {
  final PfzRepository repository;
  GetZonesForDateUseCase(this.repository);

  Future<Either<Failure, List<PfzPick>>> call(DateTime date, {String? species}) =>
      repository.getPicksForDate(date, species: species);
}
