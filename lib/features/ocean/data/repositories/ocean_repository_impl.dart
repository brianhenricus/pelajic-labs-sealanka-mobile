import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/ocean/data/datasources/ocean_remote_datasource.dart';
import 'package:sea_lanka/features/ocean/domain/entities/ocean_current.dart';
import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';
import 'package:sea_lanka/features/ocean/domain/repositories/ocean_repository.dart';

class OceanRepositoryImpl implements OceanRepository {
  final OceanRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  OceanRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, OceanCurrent>> getCurrent({required double lat, required double lon}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.getCurrent(lat: lat, lon: lon);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<TidePrediction>>> getTides({required double lat, required double lon}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.getTides(lat: lat, lon: lon);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
