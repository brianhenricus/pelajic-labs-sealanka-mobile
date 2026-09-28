import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/alerts/domain/entities/safety_alert.dart';
import 'package:sea_lanka/features/alerts/domain/repositories/alerts_repository.dart';

class GetAlertsUseCase {
  final AlertsRepository repository;
  GetAlertsUseCase(this.repository);

  Future<Either<Failure, List<SafetyAlert>>> call() => repository.getAlerts();
}
