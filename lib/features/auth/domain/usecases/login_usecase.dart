import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/auth/domain/entities/user.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  Future<Either<Failure, User>> call(LoginParams params) =>
      repository.login(phone: params.phone, password: params.password);
}

class LoginParams extends Equatable {
  final String phone;
  final String password;
  const LoginParams({required this.phone, required this.password});

  @override
  List<Object> get props => [phone, password];
}
