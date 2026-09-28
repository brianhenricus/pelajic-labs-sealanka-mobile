import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:sea_lanka/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:sea_lanka/features/auth/data/models/user_model.dart';
import 'package:sea_lanka/features/auth/domain/entities/user.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, User>> login(
      {required String phone, required String password}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final data =
          await remoteDataSource.login(phone: phone, password: password);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await localDataSource.cacheUser(
        user,
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithGoogle() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final data = await remoteDataSource.loginWithGoogle();
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await localDataSource.cacheUser(
        user,
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, User>> signup({
    required String name,
    required String phone,
    required String password,
    String? boatName,
    String? registrationNo,
    String? homeHarbour,
    String? fishingType,
    List<String>? fishingDistricts,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final data = await remoteDataSource.signup(
        name: name,
        phone: phone,
        password: password,
        boatName: boatName,
        registrationNo: registrationNo,
        homeHarbour: homeHarbour,
        fishingType: fishingType,
        fishingDistricts: fishingDistricts,
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await localDataSource.cacheUser(
        user,
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final refreshToken = await localDataSource.getRefreshToken();
      await remoteDataSource.logout(refreshToken: refreshToken);
      await localDataSource.clearUser();
      return const Right(null);
    } on ServerException catch (e) {
      await localDataSource.clearUser();
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String?>> loginWithOtpRequest(String phone) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final otp = await remoteDataSource.loginWithOtpRequest(phone);
      return Right(otp);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithOtpVerify(
      {required String phone, required String otp}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final data =
          await remoteDataSource.loginWithOtpVerify(phone: phone, otp: otp);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await localDataSource.cacheUser(
        user,
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await localDataSource.getCachedUser();
      return Right(user);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String?>> sendOtp(String phone) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final otp = await remoteDataSource.sendOtp(phone);
      return Right(otp);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> verifyOtp(
      {required String phone, required String otp}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.verifyOtp(phone: phone, otp: otp);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String?>> setPhone(String phone) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      final otp = await remoteDataSource.setPhone(phone);
      final cached = await localDataSource.getCachedUser();
      if (cached != null) {
        await localDataSource.updateCachedUser(UserModel(
          id: cached.id,
          name: cached.name,
          phone: phone,
          email: cached.email,
          avatarUrl: cached.avatarUrl,
          subscriptionTier: cached.subscriptionTier,
          boatName: cached.boatName,
          registrationNo: cached.registrationNo,
          homeHarbour: cached.homeHarbour,
          fishingType: cached.fishingType,
          fishingDistricts: cached.fishingDistricts,
          phoneVerified: false,
          createdAt: cached.createdAt,
        ));
      }
      return Right(otp);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> markPhoneVerified() async {
    final cached = await localDataSource.getCachedUser();
    if (cached == null) return const Right(null);
    await localDataSource.updateCachedUser(UserModel(
      id: cached.id,
      name: cached.name,
      phone: cached.phone,
      email: cached.email,
      avatarUrl: cached.avatarUrl,
      subscriptionTier: cached.subscriptionTier,
      boatName: cached.boatName,
      registrationNo: cached.registrationNo,
      homeHarbour: cached.homeHarbour,
      fishingType: cached.fishingType,
      fishingDistricts: cached.fishingDistricts,
      phoneVerified: true,
      createdAt: cached.createdAt,
    ));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> resetPassword(
      {required String phone,
      required String otp,
      required String newPassword}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }
    try {
      await remoteDataSource.resetPassword(
          phone: phone, otp: otp, newPassword: newPassword);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
