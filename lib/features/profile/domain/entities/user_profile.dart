import 'package:equatable/equatable.dart';

/// Aggregated profile shown on the Profile screen: identity, membership,
/// lifetime stats, and user preferences.
class UserProfile extends Equatable {
  final String id;
  final String name;
  // Nullable: a Google sign-in account has no phone number until added.
  final String? phone;
  final String? email;
  final String? avatarUrl;

  // Membership
  final String planName; // e.g. "Pro plan"
  final bool subscriptionActive;
  final DateTime memberSince;

  // Lifetime stats
  final int totalTrips;
  final int totalCatch;
  final double totalWeightKg;

  // Preferences
  final String language; // "English"
  final String units; // "Metric"
  final String homePort; // "Negombo"

  // Boat/vessel details — required for profile_complete; collected at
  // signup for phone/password accounts, missing for Google sign-in until
  // filled in via the completion page.
  final String? boatName;
  final String? registrationNo;
  final String? homeHarbour;
  final String? fishingType;
  final List<String>? fishingDistricts;

  // Feeds the PFZ "navigate to zone" fuel/time estimate. Optional — a
  // generic small-boat default is used when either is null.
  final double? fuelConsumptionLph;
  final double? cruisingSpeedKnots;

  // Server-computed: true once boat_name/registration_no/home_harbour/
  // fishing_type are all set.
  final bool profileComplete;

  const UserProfile({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.planName,
    required this.subscriptionActive,
    required this.memberSince,
    required this.totalTrips,
    required this.totalCatch,
    required this.totalWeightKg,
    required this.language,
    required this.units,
    required this.homePort,
    this.boatName,
    this.registrationNo,
    this.homeHarbour,
    this.fishingType,
    this.fishingDistricts,
    this.fuelConsumptionLph,
    this.cruisingSpeedKnots,
    required this.profileComplete,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        avatarUrl,
        planName,
        subscriptionActive,
        memberSince,
        totalTrips,
        totalCatch,
        totalWeightKg,
        language,
        units,
        homePort,
        boatName,
        registrationNo,
        homeHarbour,
        fishingType,
        fishingDistricts,
        fuelConsumptionLph,
        cruisingSpeedKnots,
        profileComplete,
      ];
}
