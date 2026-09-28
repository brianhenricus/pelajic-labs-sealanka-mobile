import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/wind/data/datasources/wind_remote_datasource.dart';
import 'package:sea_lanka/features/wind/domain/entities/wind_data.dart';
import 'package:sea_lanka/features/wind/domain/repositories/wind_repository.dart';

class WindRepositoryImpl implements WindRepository {
  final WindRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  WindRepositoryImpl({required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, WindData>> getCurrentWind({required double lat, required double lon}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.getCurrentWind(lat: lat, lon: lon);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
