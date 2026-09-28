import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/auth/domain/entities/user.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';

class SignupUseCase {
  final AuthRepository repository;
  SignupUseCase(this.repository);

  Future<Either<Failure, User>> call(SignupParams params) => repository.signup(
        name: params.name,
        phone: params.phone,
        password: params.password,
        boatName: params.boatName,
        registrationNo: params.registrationNo,
        homeHarbour: params.homeHarbour,
        fishingType: params.fishingType,
        fishingDistricts: params.fishingDistricts,
      );
}

class SignupParams extends Equatable {
  final String name;
  final String phone;
  final String password;
  final String? boatName;
  final String? registrationNo;
  final String? homeHarbour;
  final String? fishingType;
  final List<String>? fishingDistricts;
  const SignupParams({
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
