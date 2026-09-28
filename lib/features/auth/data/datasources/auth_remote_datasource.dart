import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sea_lanka/core/constants/google_config.dart';
import 'package:sea_lanka/core/device/device_id_provider.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(
      {required String phone, required String password});

  /// Runs the native Google account picker, then exchanges the resulting ID
  /// token with the backend for our own access/refresh tokens. Throws
  /// [ServerException] both for a real backend rejection and for the user
  /// simply cancelling the picker (surfaced as a generic "cancelled"
  /// message) -- callers don't need to distinguish those.
  Future<Map<String, dynamic>> loginWithGoogle();

  Future<Map<String, dynamic>> signup({
    required String name,
    required String phone,
    required String password,
    String? boatName,
    String? registrationNo,
    String? homeHarbour,
    String? fishingType,
    List<String>? fishingDistricts,
  });

  Future<void> logout({required String? refreshToken});

  /// First half of passwordless login -- an OTP for an *existing* account
  /// only (404s for an unregistered phone, unlike [sendOtp]). Returns the
  /// OTP itself only in development, same as [sendOtp].
  Future<String?> loginWithOtpRequest(String phone);

  /// Second half: verifying the OTP doubles as proof of identity and logs
  /// the user in, same response shape as [login]/[signup].
  Future<Map<String, dynamic>> loginWithOtpVerify(
      {required String phone, required String otp});

  /// Returns the OTP itself only in development (settings.expose_otp_in_response
  /// on the backend) -- null in every other environment, since real SMS
  /// delivery is how the code actually reaches the user otherwise.
  Future<String?> sendOtp(String phone);

  /// For an account with no phone on file (Google sign-in) to add one --
  /// backend resets phone_verified to false and sends a fresh OTP. Returns
  /// the OTP itself only in development, same as [sendOtp].
  Future<String?> setPhone(String phone);

  Future<void> verifyOtp({required String phone, required String otp});

  Future<void> resetPassword(
      {required String phone,
      required String otp,
      required String newPassword});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;
  final DeviceIdProvider _deviceIdProvider;
  AuthRemoteDataSourceImpl(this._dio, this._deviceIdProvider);

  @override
  Future<Map<String, dynamic>> login(
      {required String phone, required String password}) async {
    try {
      final deviceId = await _deviceIdProvider.getOrCreate();
      final response = await _dio.post(ApiEndpoints.login, data: {
        'phone': phone,
        'password': password,
        'device_id': deviceId,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // FastAPI's default error shape is {"detail": "..."} (HTTPException),
      // not {"message": ...} -- reading the wrong key silently swallowed
      // real backend messages like "Invalid phone or password" or
      // "Too many attempts. Try again later." behind a generic fallback.
      throw ServerException(e.response?.data?['detail'] ?? 'Login failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<Map<String, dynamic>> signup({
    required String name,
    required String phone,
    required String password,
    String? boatName,
    String? registrationNo,
    String? homeHarbour,
    String? fishingType,
    List<String>? fishingDistricts,
  }) async {
    try {
      final deviceId = await _deviceIdProvider.getOrCreate();
      final response = await _dio.post(ApiEndpoints.signup, data: {
        'name': name,
        'phone': phone,
        'password': password,
        'device_id': deviceId,
        'boat_name': boatName,
        'registration_no': registrationNo,
        'home_harbour': homeHarbour,
        'fishing_type': fishingType,
        'fishing_districts': fishingDistricts,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Signup failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<Map<String, dynamic>> loginWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: GoogleConfig.webClientId,
    );
    try {
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User dismissed the account picker -- not an error, just a no-op
        // the caller reports the same way as any other login failure.
        throw ServerException('Sign-in cancelled', null);
      }
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw ServerException('Google sign-in did not return a token', null);
      }

      final deviceId = await _deviceIdProvider.getOrCreate();
      final response = await _dio.post(ApiEndpoints.googleLogin,
          data: {'id_token': idToken, 'device_id': deviceId});
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Google sign-in failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<void> logout({required String? refreshToken}) async {
    // Google Sign-In caches the last-used account natively (independent of
    // this Dart GoogleSignIn instance) -- without signing out here too, the
    // next loginWithGoogle() call silently re-authenticates the same
    // account instead of showing the picker, even after this app-level
    // logout. Never lets a Google-side failure (e.g. never signed in via
    // Google) block the actual logout.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    try {
      await _dio
          .post(ApiEndpoints.logout, data: {'refresh_token': refreshToken});
    } on DioException catch (e) {
      throw ServerException('Logout failed', e.response?.statusCode);
    }
  }

  @override
  Future<String?> loginWithOtpRequest(String phone) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.loginOtpRequest, data: {'phone': phone});
      return response.data?['otp'] as String?;
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Send OTP failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<Map<String, dynamic>> loginWithOtpVerify(
      {required String phone, required String otp}) async {
    try {
      final deviceId = await _deviceIdProvider.getOrCreate();
      final response = await _dio.post(ApiEndpoints.loginOtpVerify, data: {
        'phone': phone,
        'otp': otp,
        'device_id': deviceId,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'OTP verification failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<String?> sendOtp(String phone) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.sendOtp, data: {'phone': phone});
      return response.data?['otp'] as String?;
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Send OTP failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<String?> setPhone(String phone) async {
    try {
      final response =
          await _dio.post(ApiEndpoints.setPhone, data: {'phone': phone});
      return response.data?['otp'] as String?;
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Set phone failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<void> verifyOtp({required String phone, required String otp}) async {
    try {
      await _dio
          .post(ApiEndpoints.verifyOtp, data: {'phone': phone, 'otp': otp});
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'OTP verification failed',
          e.response?.statusCode);
    }
  }

  @override
  Future<void> resetPassword(
      {required String phone,
      required String otp,
      required String newPassword}) async {
    try {
      await _dio.post(ApiEndpoints.resetPassword, data: {
        'phone': phone,
        'otp': otp,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw ServerException('Password reset failed', e.response?.statusCode);
    }
  }
}
