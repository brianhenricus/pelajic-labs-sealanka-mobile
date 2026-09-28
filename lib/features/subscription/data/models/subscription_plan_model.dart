import 'package:sea_lanka/features/subscription/domain/entities/subscription_plan.dart';

class SubscriptionPlanModel extends SubscriptionPlan {
  const SubscriptionPlanModel({
    required super.id,
    required super.name,
    required super.priceMonthly,
    required super.currency,
    required super.features,
    required super.isPopular,
    required super.maxDevices,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlanModel(
        id: json['id'] as String,
        name: json['name'] as String,
        priceMonthly: (json['price_monthly'] as num).toDouble(),
        currency: json['currency'] as String,
        features: (json['features'] as List).map((e) => e as String).toList(),
        isPopular: json['is_popular'] as bool,
        maxDevices: json['max_devices'] as int,
      );
}

class SubscriptionPlansResultModel extends SubscriptionPlansResult {
  const SubscriptionPlansResultModel({
    required super.plans,
    required super.trialEndsAt,
    required super.isTrialActive,
  });

  factory SubscriptionPlansResultModel.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlansResultModel(
        plans: (json['plans'] as List)
            .map((e) =>
                SubscriptionPlanModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        trialEndsAt: DateTime.parse(json['trial_ends_at'] as String),
        isTrialActive: json['is_trial_active'] as bool,
      );
}

class MySubscriptionModel extends MySubscription {
  const MySubscriptionModel({
    required super.planId,
    required super.planName,
    required super.renewsAt,
    required super.reminderDue,
    required super.inGrace,
    required super.graceDaysLeft,
  });

  factory MySubscriptionModel.fromJson(Map<String, dynamic> json) =>
      MySubscriptionModel(
        planId: json['plan_id'] as String,
        planName: json['plan_name'] as String,
        renewsAt: json['renews_at'] != null
            ? DateTime.parse(json['renews_at'] as String)
            : null,
        reminderDue: json['reminder_due'] as bool,
        inGrace: json['in_grace'] as bool,
        graceDaysLeft: json['grace_days_left'] as int?,
      );
}
