import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/home/data/datasources/home_remote_datasource.dart';
import 'package:sea_lanka/features/home/domain/entities/fishing_condition.dart';
import 'package:sea_lanka/features/home/domain/entities/weather_summary.dart';
import 'package:sea_lanka/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  HomeRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, WeatherSummary>> getWeatherSummary(
      {required double lat, required double lon}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result =
          await remoteDataSource.getWeatherSummary(lat: lat, lon: lon);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, FishingCondition>> getFishingCondition(
      {required double lat, required double lon}) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result =
          await remoteDataSource.getFishingCondition(lat: lat, lon: lon);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
