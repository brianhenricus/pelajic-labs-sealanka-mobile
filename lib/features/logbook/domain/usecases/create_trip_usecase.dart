import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';
import 'package:sea_lanka/features/logbook/domain/repositories/logbook_repository.dart';

class CreateTripUseCase {
  final LogbookRepository repository;
  CreateTripUseCase(this.repository);

  Future<Either<Failure, TripLog>> call(CreateTripParams params) =>
      repository.createTrip(
        date: params.date,
        location: params.location,
        lat: params.lat,
        lon: params.lon,
        catches: params.catches,
        notes: params.notes,
        photoUrls: params.photoUrls,
        durationMinutes: params.durationMinutes,
        fuelLiters: params.fuelLiters,
        followedPredictionId: params.followedPredictionId,
      );
}

class CreateTripParams extends Equatable {
  final DateTime date;
  final String location;
  final double lat;
  final double lon;
  final List<CatchEntry> catches;
  final String? notes;
  final List<String> photoUrls;
  final int durationMinutes;
  final double? fuelLiters;
  final String? followedPredictionId;

  const CreateTripParams({
    required this.date,
    required this.location,
    required this.lat,
    required this.lon,
    required this.catches,
    this.notes,
    required this.photoUrls,
    required this.durationMinutes,
    this.fuelLiters,
    this.followedPredictionId,
  });

  @override
  List<Object?> get props => [
        date,
        location,
        lat,
        lon,
        catches,
        notes,
        photoUrls,
        durationMinutes,
        fuelLiters,
        followedPredictionId,
      ];
}
