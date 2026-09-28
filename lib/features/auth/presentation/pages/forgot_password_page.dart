import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/utils/phone_utils.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/auth_decor.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/otp_input_widget.dart';

/// Ports the 3-screen auth-flow.html mockup: Forgot Password -> Verify OTP ->
/// Set New Password, ending with a success overlay that auto-redirects.
enum _Stage { phone, otp, newPassword, success }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authRepository = sl<AuthRepository>();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  _Stage _stage = _Stage.phone;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _otpComplete = false;
  String _otp = '';
  String? _errorMessage;
  Timer? _resendTimer;
  int _resendSecondsLeft = 45;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository
        .sendOtp(normalizePhoneOrEmail(_phoneController.text));
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
        .sendOtp(normalizePhoneOrEmail(_phoneController.text));
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _errorMessage = failure.message),
      (_) => _startResendCountdown(),
    );
  }

  Future<void> _verifyOtp() async {
    if (!_otpComplete) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository.verifyOtp(
      phone: normalizePhoneOrEmail(_phoneController.text),
      otp: _otp,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (_) => setState(() {
        _isLoading = false;
        _stage = _Stage.newPassword;
      }),
    );
  }

  Future<void> _resetPassword() async {
    if (!_passwordRulesMet ||
        _newPasswordController.text != _confirmController.text) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authRepository.resetPassword(
      phone: normalizePhoneOrEmail(_phoneController.text),
      otp: _otp,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (_) async {
        setState(() {
          _isLoading = false;
          _stage = _Stage.success;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go(AppRoutes.login);
      },
    );
  }

  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUppercase =>
      _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _newPasswordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get _passwordRulesMet =>
      _hasMinLength && _hasUppercase && _hasNumber && _hasSpecialChar;

  double get _strengthScore {
    final rules = [_hasMinLength, _hasUppercase, _hasNumber, _hasSpecialChar];
    return rules.where((r) => r).length / rules.length;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackdrop()),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero — back + icon + title + subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    child: _BackButton(
                      onTap: () {
                        if (_stage == _Stage.phone) {
                          context.pop();
                        } else {
                          setState(() => _stage = _Stage.phone);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HeroIcon(stage: _stage),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              switch (_stage) {
                                _Stage.phone => t.forgotPassword,
                                _Stage.otp => t.verifyCodeTitle,
                                _Stage.newPassword ||
                                _Stage.success =>
                                  t.createNewPasswordTitle,
                              },
                              textAlign: TextAlign.center,
                              style: AppTextStyles.h1(locale)
                                  .copyWith(color: AppColors.white),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              switch (_stage) {
                                _Stage.phone => t.forgotPasswordSubtitle,
                                _Stage.otp =>
                                  '${t.sentToPrefix}${_maskedPhone()}',
                                _Stage.newPassword ||
                                _Stage.success =>
                                  t.createNewPasswordSubtitle,
                              },
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(locale)
                                  .copyWith(color: AppColors.skyBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Card
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppSpacing.radiusXl)),
                            boxShadow: AppShadows.sheet,
                          ),
                          padding: EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.xl,
                              AppSpacing.xl,
                              AppSpacing.lg +
                                  MediaQuery.of(context).padding.bottom),
                          // The card's height is fixed (Expanded flex:3
                          // above), but its content isn't -- the OTP stage's
                          // dev banner, longer Sinhala/Tamil strings, a
                          // shorter/smaller device, or the keyboard opening
                          // can all push content past that fixed height.
                          // LayoutBuilder + ConstrainedBox(minHeight) keeps
                          // the existing Spacer-based bottom-anchored button
                          // layout on screens with room, and lets it scroll
                          // instead of overflow on screens without.
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight),
                                child: IntrinsicHeight(
                                  child: _buildStageBody(context, locale, t),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_stage == _Stage.success)
                          Positioned.fill(
                            child: _SuccessOverlay(t: t, locale: locale),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Masks the normalized phone for display, e.g. +94771234567 -> *** 4567.
  /// Was previously hardcoded to a fake "77 ***" prefix regardless of the
  /// number actually entered -- this reads the real last 4 digits only.
  String _maskedPhone() {
    final digits = normalizePhoneOrEmail(_phoneController.text)
        .replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return _phoneController.text;
    return '*** ${digits.substring(digits.length - 4)}';
  }

  Widget? _buildErrorBanner(Locale locale) {
    if (_errorMessage == null) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Text(
        _errorMessage!,
        style: AppTextStyles.caption(locale).copyWith(color: AppColors.danger),
      ),
    );
  }

  Widget _buildStageBody(
      BuildContext context, Locale locale, AppLocalizations t) {
    final errorBanner = _buildErrorBanner(locale);
    switch (_stage) {
      case _Stage.phone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorBanner != null) errorBanner,
            SlTextField(
              controller: _phoneController,
              label: t.phoneNumber,
              hint: '77 123 4567',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const Spacer(),
            SeaLankaButton(
              label: t.sendOtpCode,
              variant: SeaLankaButtonVariant.cta,
              isLoading: _isLoading,
              onPressed: _sendOtp,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  '← ${t.backToSignIn}',
                  style: AppTextStyles.body(locale).copyWith(
                    color: AppColors.fg3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      case _Stage.otp:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorBanner != null) errorBanner,
            const SizedBox(height: AppSpacing.sm),
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
                          style: AppTextStyles.caption(locale).copyWith(
                              color: AppColors.marineBlue,
                              fontWeight: FontWeight.w600)),
                    ),
            ),
            const Spacer(),
            SeaLankaButton(
              label: t.verifyCodeCta,
              variant: SeaLankaButtonVariant.cta,
              isLoading: _isLoading,
              onPressed: _otpComplete ? _verifyOtp : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _stage = _Stage.phone),
                child: Text(
                  '← ${t.changePhoneNumber}',
                  style: AppTextStyles.body(locale).copyWith(
                    color: AppColors.fg3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      case _Stage.newPassword:
      case _Stage.success:
        final strengthLabel = _strengthScore >= 1.0
            ? t.passwordStrengthStrong
            : _strengthScore >= 0.5
                ? t.passwordStrengthFair
                : t.passwordStrengthWeak;
        final strengthColor = _strengthScore >= 1.0
            ? AppColors.success
            : _strengthScore >= 0.5
                ? AppColors.warning
                : AppColors.danger;
        final passwordsMatch = _confirmController.text.isNotEmpty &&
            _confirmController.text == _newPasswordController.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (errorBanner != null) errorBanner,
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _strengthScore,
                minHeight: 6,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation(strengthColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${t.strengthLabel}$strengthLabel',
                style: AppTextStyles.caption(locale).copyWith(
                    color: strengthColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            SlTextField(
              controller: _newPasswordController,
              label: t.newPassword,
              obscureText: _obscureNew,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: IconButton(
                icon: Icon(
                    _obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            SlTextField(
              controller: _confirmController,
              label: t.confirmPassword,
              obscureText: _obscureNew,
              prefixIcon: passwordsMatch
                  ? Icons.check_circle_rounded
                  : Icons.lock_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.base),
            _RuleRow(label: t.ruleMinChars, met: _hasMinLength),
            _RuleRow(label: t.ruleUppercase, met: _hasUppercase),
            _RuleRow(label: t.ruleNumber, met: _hasNumber),
            _RuleRow(label: t.ruleSpecialChar, met: _hasSpecialChar),
            const Spacer(),
            SeaLankaButton(
              label: t.resetPassword,
              variant: SeaLankaButtonVariant.cta,
              isLoading: _isLoading,
              onPressed:
                  (_passwordRulesMet && passwordsMatch) ? _resetPassword : null,
            ),
          ],
        );
    }
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child:
            const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String label;
  final bool met;
  const _RuleRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: met ? AppColors.success : AppColors.borderLight,
          ),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.fg2,
              )),
        ],
      ),
    );
  }
}

/// Hero icon disc — broken-lock (phone stage), rippling smartphone (otp
/// stage), or shield-check (new-password stage). Ported from auth-flow.html.
class _HeroIcon extends StatefulWidget {
  final _Stage stage;
  const _HeroIcon({required this.stage});

  @override
  State<_HeroIcon> createState() => _HeroIconState();
}

class _HeroIconState extends State<_HeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rippling = widget.stage == _Stage.otp;
    final (accent, icon) = switch (widget.stage) {
      _Stage.phone => (AppColors.coralGold, Icons.lock_outline_rounded),
      _Stage.otp => (AppColors.marineBlue, Icons.smartphone_rounded),
      _Stage.newPassword || _Stage.success => (
          AppColors.success,
          Icons.shield_rounded
        ),
    };
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (rippling)
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  final t = (_ctrl.value + i / 3) % 1.0;
                  return CustomPaint(
                    size: const Size(120, 120),
                    painter: _RipplePainter(t, accent),
                  );
                },
              );
            }),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t; // 0..1
  final Color color;
  _RipplePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = 40 + (size.width / 2 - 40) * t;
    final opacity = (0.5 * (1 - t)).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withOpacity(opacity);
    canvas.drawCircle(center, baseR, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.t != t || old.color != color;
}

/// Full-screen success overlay shown after a successful password reset,
/// matching `.success-overlay` in auth-flow.html.
class _SuccessOverlay extends StatelessWidget {
  final AppLocalizations t;
  final Locale locale;
  const _SuccessOverlay({required this.t, required this.locale});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              t.passwordUpdated,
              style: AppTextStyles.h2(locale).copyWith(color: AppColors.fg1),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              t.redirectingSignIn,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg3),
            ),
            const SizedBox(height: AppSpacing.base),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i < 3 ? AppColors.success : AppColors.borderLight,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
