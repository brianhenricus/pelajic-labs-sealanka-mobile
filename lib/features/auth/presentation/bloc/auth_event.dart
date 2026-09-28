part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String phone;
  final String password;
  const AuthLoginRequested({required this.phone, required this.password});
  @override
  List<Object> get props => [phone, password];
}

class AuthGoogleLoginRequested extends AuthEvent {}

class AuthSignupRequested extends AuthEvent {
  final String name;
  final String phone;
  final String password;
  final String? boatName;
  final String? registrationNo;
  final String? homeHarbour;
  final String? fishingType;
  final List<String>? fishingDistricts;
  const AuthSignupRequested({
    required this.name,
    required this.phone,
    required this.password,
    this.boatName,
    this.registrationNo,
    this.homeHarbour,
    this.fishingType,
    this.fishingDistricts,
  });
  @override
  List<Object?> get props => [
        name,
        phone,
        password,
        boatName,
        registrationNo,
        homeHarbour,
        fishingType,
        fishingDistricts,
      ];
}

class AuthLogoutRequested extends AuthEvent {}
