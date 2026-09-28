part of 'subscription_bloc.dart';

abstract class SubscriptionState extends Equatable {
  const SubscriptionState();
  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {}

class SubscriptionLoading extends SubscriptionState {}

class SubscriptionLoaded extends SubscriptionState {
  final List<SubscriptionPlan> plans;
  final DateTime trialEndsAt;
  final bool isTrialActive;
  const SubscriptionLoaded(this.plans, this.trialEndsAt, this.isTrialActive);

  @override
  List<Object?> get props => [plans, trialEndsAt, isTrialActive];
}

class SubscriptionError extends SubscriptionState {
  final String message;
  const SubscriptionError(this.message);

  @override
  List<Object?> get props => [message];
}
