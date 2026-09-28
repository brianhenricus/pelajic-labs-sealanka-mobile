import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/logbook/data/datasources/logbook_remote_datasource.dart';
import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';
import 'package:sea_lanka/features/logbook/domain/repositories/logbook_repository.dart';

class LogbookRepositoryImpl implements LogbookRepository {
  final LogbookRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  LogbookRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, List<TripLog>>> getTrips() async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.getTrips();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TripLog>> createTrip({
    required DateTime date,
    required String location,
    required double lat,
    required double lon,
    required List<CatchEntry> catches,
    String? notes,
    required List<String> photoUrls,
    required int durationMinutes,
    double? fuelLiters,
    String? followedPredictionId,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDataSource.createTrip(
        date: date,
        location: location,
        lat: lat,
        lon: lon,
        catches: catches,
        notes: notes,
        photoUrls: photoUrls,
        durationMinutes: durationMinutes,
        fuelLiters: fuelLiters,
        followedPredictionId: followedPredictionId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
