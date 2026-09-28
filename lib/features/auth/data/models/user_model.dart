import 'package:sea_lanka/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    super.phone,
    super.email,
    super.avatarUrl,
    super.subscriptionTier,
    super.boatName,
    super.registrationNo,
    super.homeHarbour,
    super.fishingType,
    super.fishingDistricts,
    required super.phoneVerified,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        // Backend never sends this (no such concept exists there) -- the
        // 'free' default lives in the entity's isPro/isBasic getters, not
        // baked in here, so there's exactly one place that decides it.
        subscriptionTier: json['subscription_tier'] as String?,
        boatName: json['boat_name'] as String?,
        registrationNo: json['registration_no'] as String?,
        homeHarbour: json['home_harbour'] as String?,
        fishingType: json['fishing_type'] as String?,
        fishingDistricts:
            (json['fishing_districts'] as List<dynamic>?)?.cast<String>(),
        // Defaults false for any cached blob written before this field
        // existed -- forces a re-check (verify-phone screen) rather than
        // silently trusting a stale/missing value as "verified".
        phoneVerified: json['phone_verified'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'avatar_url': avatarUrl,
        'subscription_tier': subscriptionTier,
        'boat_name': boatName,
        'registration_no': registrationNo,
        'home_harbour': homeHarbour,
        'fishing_type': fishingType,
        'fishing_districts': fishingDistricts,
        'phone_verified': phoneVerified,
        'created_at': createdAt.toIso8601String(),
      };
}
