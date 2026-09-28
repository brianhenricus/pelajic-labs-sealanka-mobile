import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  // Nullable: a Google sign-in account has no phone number until the user
  // adds one -- nothing in the Google identity provides it.
  final String? phone;
  final String? email;
  final String? avatarUrl;
  // Nullable: the backend has no such concept (subscriptions are plan-based,
  // not stamped on the user) -- 'free' is a display default, not a real
  // field the server ever sends.
  final String? subscriptionTier;
  final String? boatName;
  final String? registrationNo;
  final String? homeHarbour;
  final String? fishingType;
  final List<String>? fishingDistricts;
  final bool phoneVerified;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.avatarUrl,
    this.subscriptionTier,
    this.boatName,
    this.registrationNo,
    this.homeHarbour,
    this.fishingType,
    this.fishingDistricts,
    required this.phoneVerified,
    required this.createdAt,
  });

  bool get isPro => subscriptionTier == 'pro';
  bool get isBasic => subscriptionTier == 'basic' || isPro;

  // Mirrors the backend's profile_complete check (see sealanka-be's
  // ProfileOut) — phone/password signup collects these up front, so this
  // is only ever false for a Google sign-in account that hasn't finished
  // the completion step yet.
  bool get needsProfileCompletion =>
      boatName == null ||
      registrationNo == null ||
      homeHarbour == null ||
      fishingType == null;

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        avatarUrl,
        subscriptionTier,
        boatName,
        registrationNo,
        homeHarbour,
        fishingType,
        fishingDistricts,
        phoneVerified,
        createdAt,
      ];
}
