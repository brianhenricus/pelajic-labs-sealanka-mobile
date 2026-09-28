import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/utils/phone_utils.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/auth/domain/entities/user.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/otp_input_widget.dart';

/// Mandatory post-signup step, server-enforced (see sealanka-be's
/// get_verified_user): PFZ/logbook/subscription all 403 with "Phone not
/// verified" until User.phone_verified is true. Reached from
/// login_page.dart/splash_page.dart when [User.phoneVerified] is false --
/// no back button, hardware back blocked (see [PopScope]), matching
/// complete_profile_page.dart's same "mandatory gate" pattern.
class VerifyPhonePage extends StatefulWidget {
  const VerifyPhonePage({super.key});

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final _authRepository = sl<AuthRepository>();
  final _phoneController = TextEditingController();
  User? _user;
  bool _isLoading = false;
  bool _otpComplete = false;
  String _otp = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final result = await _authRepository.getCurrentUser();
    final user = result.fold((_) => null, (u) => u);
    if (!mounted) return;
    setState(() => _user = user);
    final phone = user?.phone;
    if (phone != null) {
      // A fresh code -- the one sent at signup may already be minutes old
      // by the time this screen is actually reached (e.g. reopening the
      // app instead of verifying immediately).
      await _authRepository.sendOtp(phone);
    }
    // No phone yet (Google sign-in) -- stays on the phone-entry stage below
    // until _submitPhone gets one on file and an OTP goes out.
  }

  Future<void> _submitPhone() async {
    final phone = normalizePhoneOrEmail(_phoneController.text);
    if (phone.length < 7) {
      setState(() => _errorMessage = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository.setPhone(phone);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (_) => setState(() {
        _isLoading = false;
        _user = User(
          id: _user!.id,
          name: _user!.name,
          phone: phone,
          email: _user!.email,
          avatarUrl: _user!.avatarUrl,
          subscriptionTier: _user!.subscriptionTier,
          boatName: _user!.boatName,
          registrationNo: _user!.registrationNo,
          homeHarbour: _user!.homeHarbour,
          fishingType: _user!.fishingType,
          fishingDistricts: _user!.fishingDistricts,
          phoneVerified: false,
          createdAt: _user!.createdAt,
        );
      }),
    );
  }

  Future<void> _resend() async {
    final phone = _user?.phone;
    if (phone == null) return;
    setState(() => _errorMessage = null);
    final result = await _authRepository.sendOtp(phone);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (_) {},
    );
  }

  Future<void> _verify() async {
    final phone = _user?.phone;
    if (phone == null || !_otpComplete) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository.verifyOtp(phone: phone, otp: _otp);
    if (!mounted) return;
    await result.fold(
      (failure) async => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (_) async {
        await _authRepository.markPhoneVerified();
        if (!mounted) return;
        setState(() => _isLoading = false);
        // Verify-phone is only ever reached right after a phone/password
        // signup (Google accounts have no phone to verify, see
        // postAuthRoute) or a not-yet-verified account reopening the app --
        // in both cases the profile fields are already collected by the
        // signup form, so this lands on pricing next, same as signup used
        // to go straight to before this gate existed.
        context.go((_user?.needsProfileCompletion ?? false)
            ? AppRoutes.completeProfile
            : AppRoutes.subscription);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          // Same overflow risk as forgot_password_page.dart's card: a
          // Column with Spacer() and variable content (dev-otp banner,
          // error text, longer Sinhala/Tamil strings) inside a bounded
          // height -- LayoutBuilder + ConstrainedBox(minHeight) keeps the
          // Spacer-based bottom-anchored button on screens with room, and
          // lets it scroll instead of overflow on smaller screens or when
          // the keyboard opens for OTP entry.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        2 * AppSpacing.xl -
                        MediaQuery.of(context).padding.bottom),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      const Icon(Icons.smartphone_rounded,
                          size: 48, color: AppColors.marineBlue),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                          _user?.phone == null
                              ? t.enterPhoneTitle
                              : t.verifyPhoneTitle,
                          style: AppTextStyles.h1(locale)
                              .copyWith(color: AppColors.fg1)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _user?.phone == null
                            ? t.enterPhoneSubtitle
                            : t.verifyPhoneSubtitle(_user!.phone!),
                        style: AppTextStyles.body(locale)
                            .copyWith(color: AppColors.fg3),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_errorMessage != null) ...[
                        Text(_errorMessage!,
                            style: AppTextStyles.caption(locale)
                                .copyWith(color: AppColors.danger)),
                        const SizedBox(height: AppSpacing.base),
                      ],
                      if (_user?.phone == null) ...[
                        SlTextField(
                          controller: _phoneController,
                          label: t.phoneLabel,
                          hint: t.phoneHint,
                          prefixIcon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const Spacer(),
                        SeaLankaButton(
                          label: t.continueCta,
                          variant: SeaLankaButtonVariant.cta,
                          isLoading: _isLoading,
                          onPressed: _submitPhone,
                        ),
                      ] else ...[
                        OtpInputWidget(
                          onCompleted: (code) => setState(() {
                            _otp = code;
                            _otpComplete = true;
                          }),
                        ),
                        const SizedBox(height: AppSpacing.base),
                        Center(
                          child: TextButton(
                            onPressed: _resend,
                            child: Text(t.resendCode,
                                style: AppTextStyles.body(locale)
                                    .copyWith(color: AppColors.marineBlue)),
                          ),
                        ),
                        const Spacer(),
                        SeaLankaButton(
                          label: t.verifyCodeCta,
                          variant: SeaLankaButtonVariant.cta,
                          isLoading: _isLoading,
                          onPressed: _otpComplete ? _verify : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
