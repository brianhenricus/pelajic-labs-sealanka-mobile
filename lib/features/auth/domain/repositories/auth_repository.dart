import 'package:dartz/dartz.dart';
import 'package:sea_lanka/core/error/failures.dart';
import 'package:sea_lanka/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login({
    required String phone,
    required String password,
  });

  Future<Either<Failure, User>> loginWithGoogle();

  Future<Either<Failure, User>> signup({
    required String name,
    required String phone,
    required String password,
    String? boatName,
    String? registrationNo,
    String? homeHarbour,
    String? fishingType,
    List<String>? fishingDistricts,
  });

  Future<Either<Failure, void>> logout();

  /// First half of passwordless login -- an OTP for an *existing* account
  /// only (fails for an unregistered phone). Returned String is the OTP
  /// itself, dev-only, same rule as [sendOtp].
  Future<Either<Failure, String?>> loginWithOtpRequest(String phone);

  /// Second half: verifying the OTP doubles as proof of identity and logs
  /// the user in, caching the session like [login]/[signup].
  Future<Either<Failure, User>> loginWithOtpVerify({
    required String phone,
    required String otp,
  });

  Future<Either<Failure, User?>> getCurrentUser();

  /// The returned String is the OTP itself, only ever non-null in
  /// development (see settings.expose_otp_in_response on the backend) --
  /// null in every other environment, since real SMS delivery is how the
  /// code actually reaches the user otherwise.
  Future<Either<Failure, String?>> sendOtp(String phone);

  /// Adds a phone to an account that has none (Google sign-in) so it can
  /// then go through the same mandatory OTP verification. Sends a fresh
  /// OTP server-side and updates the locally cached user's phone. The
  /// returned String is the OTP itself, same dev-only rule as [sendOtp].
  Future<Either<Failure, String?>> setPhone(String phone);

  Future<Either<Failure, void>> verifyOtp({
    required String phone,
    required String otp,
  });

  /// Patches the locally cached user's phoneVerified flag to true after a
  /// successful verifyOtp -- otherwise a closed-and-reopened app would keep
  /// reading the stale (unverified) cached user and loop back to the
  /// verify-phone screen forever, even though the server already knows
  /// they're verified. No-op if nothing is cached (shouldn't happen mid-flow).
  Future<Either<Failure, void>> markPhoneVerified();

  Future<Either<Failure, void>> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  });
}
