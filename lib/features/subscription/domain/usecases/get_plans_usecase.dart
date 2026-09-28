import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/subscription/domain/entities/subscription_plan.dart';
import 'package:sea_lanka/features/subscription/domain/repositories/subscription_repository.dart';

class GetPlansUseCase {
  final SubscriptionRepository repository;
  GetPlansUseCase(this.repository);

  Future<Either<Failure, SubscriptionPlansResult>> call() =>
      repository.getPlans();
}
