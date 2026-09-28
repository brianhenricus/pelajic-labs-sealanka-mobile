import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';
import 'package:sea_lanka/features/logbook/domain/repositories/logbook_repository.dart';

class GetTripsUseCase {
  final LogbookRepository repository;
  GetTripsUseCase(this.repository);

  Future<Either<Failure, List<TripLog>>> call() => repository.getTrips();
}
