import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';

abstract class PfzRepository {
  Future<Either<Failure, List<PfzPick>>> getPicksForDate(DateTime date, {String? species});
  Future<Either<Failure, PfzPick>> getPickDetail(String pickId);
}
