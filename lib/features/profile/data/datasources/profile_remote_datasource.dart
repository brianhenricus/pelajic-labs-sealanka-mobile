import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/profile/data/models/user_profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserProfileModel> getProfile();
  Future<UserProfileModel> updateProfile(Map<String, dynamic> patch);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio _dio;
  ProfileRemoteDataSourceImpl(this._dio);

  @override
  Future<UserProfileModel> getProfile() async {
    try {
      final response = await _dio.get(ApiEndpoints.profile);
      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Profile unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<UserProfileModel> updateProfile(Map<String, dynamic> patch) async {
    try {
      final response = await _dio.patch(ApiEndpoints.profile, data: patch);
      return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Profile update failed',
          e.response?.statusCode);
    }
  }
}
