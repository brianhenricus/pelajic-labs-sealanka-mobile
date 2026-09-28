import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/solunar/data/datasources/solunar_remote_datasource.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_snapshot.dart';
import 'package:sea_lanka/features/solunar/domain/repositories/solunar_repository.dart';

class SolunarRepositoryImpl implements SolunarRepository {
  final SolunarRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  SolunarRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, SolunarSnapshot>> getSolunar(
      {required double lat, required double lon, DateTime? date}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result =
          await remoteDataSource.getSolunar(lat: lat, lon: lon, date: date);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
