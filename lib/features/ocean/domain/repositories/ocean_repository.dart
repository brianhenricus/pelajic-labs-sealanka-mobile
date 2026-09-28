import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/ocean/domain/entities/ocean_current.dart';
import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';

abstract class OceanRepository {
  Future<Either<Failure, OceanCurrent>> getCurrent({required double lat, required double lon});
  Future<Either<Failure, List<TidePrediction>>> getTides({required double lat, required double lon});
}
