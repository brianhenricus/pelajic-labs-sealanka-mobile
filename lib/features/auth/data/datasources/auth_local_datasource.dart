import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sea_lanka/features/auth/data/models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(
      UserModel user, String accessToken, String refreshToken);
  Future<UserModel?> getCachedUser();
  Future<String?> getRefreshToken();
  Future<void> clearUser();
  // Rewrites just the cached user blob (tokens untouched) -- used to patch
  // in a field that changed server-side mid-session, e.g. phoneVerified
  // after a successful OTP verify.
  Future<void> updateCachedUser(UserModel user);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _secureStorage;
  final Box _box;

  AuthLocalDataSourceImpl(this._secureStorage, this._box);

  @override
  Future<void> cacheUser(
      UserModel user, String accessToken, String refreshToken) async {
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    await _box.put('cached_user', jsonEncode(user.toJson()));
  }

  @override
  Future<UserModel?> getCachedUser() async {
    final data = _box.get('cached_user') as String?;
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  @override
  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: 'refresh_token');
  }

  @override
  Future<void> updateCachedUser(UserModel user) async {
    await _box.put('cached_user', jsonEncode(user.toJson()));
  }

  @override
  Future<void> clearUser() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _box.delete('cached_user');
  }
}
