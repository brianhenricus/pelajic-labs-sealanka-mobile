import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/profile/domain/entities/user_profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserProfile>> getProfile();
  Future<Either<Failure, UserProfile>> updateProfile(
      Map<String, dynamic> patch);
}
