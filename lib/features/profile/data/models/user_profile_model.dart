import 'package:sea_lanka/features/profile/domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.id,
    required super.name,
    super.phone,
    super.email,
    super.avatarUrl,
    required super.planName,
    required super.subscriptionActive,
    required super.memberSince,
    required super.totalTrips,
    required super.totalCatch,
    required super.totalWeightKg,
    required super.language,
    required super.units,
    required super.homePort,
    super.boatName,
    super.registrationNo,
    super.homeHarbour,
    super.fishingType,
    super.fishingDistricts,
    super.fuelConsumptionLph,
    super.cruisingSpeedKnots,
    required super.profileComplete,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      planName: json['plan_name'] as String? ?? 'Free plan',
      subscriptionActive: json['subscription_active'] as bool? ?? false,
      memberSince: DateTime.parse(json['member_since'] as String),
      totalTrips: json['total_trips'] as int? ?? 0,
      totalCatch: json['total_catch'] as int? ?? 0,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble() ?? 0,
      language: json['language'] as String? ?? 'English',
      units: json['units'] as String? ?? 'Metric',
      homePort: json['home_port'] as String? ?? '-',
      boatName: json['boat_name'] as String?,
      registrationNo: json['registration_no'] as String?,
      homeHarbour: json['home_harbour'] as String?,
      fishingType: json['fishing_type'] as String?,
      fishingDistricts: (json['fishing_districts'] as List?)?.cast<String>(),
      fuelConsumptionLph: (json['fuel_consumption_lph'] as num?)?.toDouble(),
      cruisingSpeedKnots: (json['cruising_speed_knots'] as num?)?.toDouble(),
      profileComplete: json['profile_complete'] as bool? ?? true,
    );
  }
}
