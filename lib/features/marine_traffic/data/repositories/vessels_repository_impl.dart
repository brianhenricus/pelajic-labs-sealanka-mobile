import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/marine_traffic/data/datasources/vessels_remote_datasource.dart';
import 'package:sea_lanka/features/marine_traffic/domain/entities/vessel.dart';
import 'package:sea_lanka/features/marine_traffic/domain/repositories/vessels_repository.dart';

class VesselsRepositoryImpl implements VesselsRepository {
  final VesselsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  VesselsRepositoryImpl({required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, VesselsSnapshot>> getVessels({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.getVessels(lat: lat, lon: lon, radiusKm: radiusKm);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
