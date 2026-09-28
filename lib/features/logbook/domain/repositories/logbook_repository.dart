import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';

abstract class LogbookRepository {
  Future<Either<Failure, List<TripLog>>> getTrips();

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
  });
}
