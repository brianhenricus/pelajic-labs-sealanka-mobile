import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/pfz/data/datasources/pfz_remote_datasource.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';
import 'package:sea_lanka/features/pfz/domain/repositories/pfz_repository.dart';

class PfzRepositoryImpl implements PfzRepository {
  final PfzRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  PfzRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, List<PfzPick>>> getPicksForDate(DateTime date, {String? species}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final picks = await remoteDataSource.getPicksForDate(date, species: species);
      return Right(picks);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PfzPick>> getPickDetail(String pickId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final pick = await remoteDataSource.getPickDetail(pickId);
      return Right(pick);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
