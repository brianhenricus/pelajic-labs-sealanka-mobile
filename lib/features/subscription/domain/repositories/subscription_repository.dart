import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/subscription/domain/entities/subscription_plan.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, SubscriptionPlansResult>> getPlans();
  Future<Either<Failure, MySubscription>> getMySubscription();
  Future<Either<Failure, void>> subscribe(String planId,
      {String? paymentMethodToken});
}
