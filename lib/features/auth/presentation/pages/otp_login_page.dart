import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/utils/phone_utils.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/otp_input_widget.dart';

/// Passwordless login: enter a phone already on file, receive an OTP,
/// verifying it logs the account in directly -- no password. Reached from
/// the "OTP Login" button on login_page.dart. Unlike verify_phone_page.dart
/// (a mandatory gate, no back button), this is an optional alternate path,
/// cancelable back to the phone/password login screen at any point.
enum _Stage { phone, otp }

class OtpLoginPage extends StatefulWidget {
  const OtpLoginPage({super.key});

  @override
  State<OtpLoginPage> createState() => _OtpLoginPageState();
}

class _OtpLoginPageState extends State<OtpLoginPage> {
  final _authRepository = sl<AuthRepository>();
  final _phoneController = TextEditingController();
  _Stage _stage = _Stage.phone;
  bool _isLoading = false;
  bool _otpComplete = false;
  String _otp = '';
  String? _errorMessage;
  Timer? _resendTimer;
  int _resendSecondsLeft = 45;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSecondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSecondsLeft = 0);
        return;
      }
      setState(() => _resendSecondsLeft--);
    });
  }

  Future<void> _sendOtp() async {
    final phone = normalizePhoneOrEmail(_phoneController.text);
    if (phone.length < 7) {
      setState(() => _errorMessage = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository.loginWithOtpRequest(phone);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (_) => setState(() {
        _isLoading = false;
        _stage = _Stage.otp;
        _startResendCountdown();
      }),
    );
  }

  Future<void> _resend() async {
    setState(() => _errorMessage = null);
    final result = await _authRepository
        .loginWithOtpRequest(normalizePhoneOrEmail(_phoneController.text));
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (_) => _startResendCountdown(),
    );
  }

  Future<void> _verify() async {
    if (!_otpComplete) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository.loginWithOtpVerify(
      phone: normalizePhoneOrEmail(_phoneController.text),
      otp: _otp,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (user) {
        setState(() => _isLoading = false);
        context.go(postAuthRoute(user));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        // Same overflow-safe shape as verify_phone_page.dart -- a Column
        // with Spacer() and variable content (dev-otp banner, error text)
        // inside a bounded height needs a scroll fallback for smaller
        // screens or when the keyboard opens for OTP entry.
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
                    IconButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () {
                        if (_stage == _Stage.otp) {
                          setState(() {
                            _stage = _Stage.phone;
                            _errorMessage = null;
                            _resendTimer?.cancel();
                          });
                        } else {
                          context.pop();
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.fg2, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Icon(Icons.smartphone_rounded,
                        size: 48, color: AppColors.marineBlue),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                        _stage == _Stage.phone ? t.otpLogin : t.verifyCodeTitle,
                        style: AppTextStyles.h1(locale)
                            .copyWith(color: AppColors.fg1)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _stage == _Stage.phone
                          ? t.otpLoginSubtitle
                          : t.verifyPhoneSubtitle(
                              normalizePhoneOrEmail(_phoneController.text)),
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
                    if (_stage == _Stage.phone) ...[
                      SlTextField(
                        controller: _phoneController,
                        label: t.phoneLabel,
                        hint: t.phoneHint,
                        prefixIcon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const Spacer(),
                      SeaLankaButton(
                        label: t.sendOtpCode,
                        variant: SeaLankaButtonVariant.cta,
                        isLoading: _isLoading,
                        onPressed: _sendOtp,
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
                        child: _resendSecondsLeft > 0
                            ? Text(
                                '${t.resendCodeIn}0:${_resendSecondsLeft.toString().padLeft(2, '0')}',
                                style: AppTextStyles.caption(locale)
                                    .copyWith(color: AppColors.marineBlue),
                              )
                            : TextButton(
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
    );
  }
}
