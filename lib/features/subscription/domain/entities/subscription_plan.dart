import 'package:equatable/equatable.dart';

class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final double priceMonthly;
  final String currency;
  final List<String> features;
  final bool isPopular;
  final int maxDevices;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.currency,
    required this.features,
    required this.isPopular,
    required this.maxDevices,
  });

  bool get isFree => priceMonthly == 0;

  @override
  List<Object> get props =>
      [id, name, priceMonthly, currency, features, isPopular, maxDevices];
}

/// GET /subscription/plans' full response: the plan catalog plus the
/// calling user's beta trial window (per-user, from signup -- see
/// sealanka-be's trial_status). Bundled together since the pricing page
/// needs both in the same render pass.
class SubscriptionPlansResult extends Equatable {
  final List<SubscriptionPlan> plans;
  final DateTime trialEndsAt;
  final bool isTrialActive;

  const SubscriptionPlansResult({
    required this.plans,
    required this.trialEndsAt,
    required this.isTrialActive,
  });

  @override
  List<Object> get props => [plans, trialEndsAt, isTrialActive];
}

/// GET /subscription/me -- the calling user's current plan + renewal
/// status, so the tiers page can show "your current plan" and label a
/// plan switch as "Change plan" instead of "Subscribe".
class MySubscription extends Equatable {
  final String planId;
  final String planName;
  final DateTime? renewsAt;
  final bool reminderDue;
  final bool inGrace;
  final int? graceDaysLeft;

  const MySubscription({
    required this.planId,
    required this.planName,
    required this.renewsAt,
    required this.reminderDue,
    required this.inGrace,
    required this.graceDaysLeft,
  });

  bool get isFree => planId == 'free';

  @override
  List<Object?> get props =>
      [planId, planName, renewsAt, reminderDue, inGrace, graceDaysLeft];
}
