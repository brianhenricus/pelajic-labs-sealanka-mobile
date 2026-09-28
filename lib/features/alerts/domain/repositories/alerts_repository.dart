import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/alerts/domain/entities/safety_alert.dart';

abstract class AlertsRepository {
  Future<Either<Failure, List<SafetyAlert>>> getAlerts();
}
