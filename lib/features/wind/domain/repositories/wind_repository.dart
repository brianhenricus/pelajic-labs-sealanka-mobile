import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/wind/domain/entities/wind_data.dart';

abstract class WindRepository {
  Future<Either<Failure, WindData>> getCurrentWind({required double lat, required double lon});
}
