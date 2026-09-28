import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/utils/phone_utils.dart';
import 'package:sea_lanka/core/widgets/attribution.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/auth_decor.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/social_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthLoginRequested(
            phone: normalizePhoneOrEmail(_phoneController.text),
            password: _passwordController.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(postAuthRoute(state.user));
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: Stack(
          children: [
            const Positioned.fill(child: AuthBackdrop()),
            // Positioned.fill gives this Column a bounded height so the card
            // below can Expand to the true bottom edge (its own padding
            // clears the gesture bar), instead of leaving the backdrop
            // showing through whenever hero+card content is short.
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Hero — logo + wordmark + tagline
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pagePadding,
                          AppSpacing.xl3,
                          AppSpacing.pagePadding,
                          AppSpacing.xl2),
                      child: Column(
                        children: [
                          const AuthLogoMark(),
                          const SizedBox(height: AppSpacing.md),
                          const AuthWordmark(),
                          const SizedBox(height: AppSpacing.base),
                          const AuthLangPillRow(),
                        ],
                      ),
                    ),
                    // Form card — fills all remaining space to the bottom edge.
                    Expanded(
                      child: Container(
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
                            AppSpacing.xl2 +
                                MediaQuery.of(context).padding.bottom),
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  t.welcomeBack,
                                  style: AppTextStyles.h1(locale)
                                      .copyWith(color: AppColors.fg1),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  t.signInToYourAccount,
                                  style: AppTextStyles.body(locale)
                                      .copyWith(color: AppColors.fg3),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                SlTextField(
                                  controller: _phoneController,
                                  label: t.phoneOrEmail,
                                  // Phone or email share this field, so the
                                  // keyboard can't be the numeric-only phone
                                  // pad (TextInputType.phone) -- emailAddress
                                  // gives a full keyboard with '@' AND easy
                                  // digit access, unlike phone which blocks
                                  // typing an email at all.
                                  hint: '+94 77 XXX XXXX or email',
                                  prefixIcon: Icons.person_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v?.isEmpty ?? true)
                                      ? t.enterPhoneValidation
                                      : null,
                                ),
                                const SizedBox(height: AppSpacing.base),
                                SlTextField(
                                  controller: _passwordController,
                                  label: t.password,
                                  hint: t.enterPasswordHint,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) => (v?.isEmpty ?? true)
                                      ? t.enterPasswordHint
                                      : null,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push(AppRoutes.forgotPassword),
                                    child: Text(
                                      t.forgotPassword,
                                      style:
                                          AppTextStyles.body(locale).copyWith(
                                        color: AppColors.marineBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.base),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    return SeaLankaButton(
                                      label: t.login,
                                      variant: SeaLankaButtonVariant.cta,
                                      isLoading: state is AuthLoading,
                                      onPressed: _onLogin,
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.base),
                                Row(
                                  children: [
                                    const Expanded(
                                        child: Divider(
                                            color: AppColors.borderLight)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm),
                                      child: Text(
                                        t.orContinueWith,
                                        style: AppTextStyles.caption(locale)
                                            .copyWith(color: AppColors.fg3),
                                      ),
                                    ),
                                    const Expanded(
                                        child: Divider(
                                            color: AppColors.borderLight)),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.base),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SocialLoginButton(
                                        label: 'Google',
                                        icon: const Text(
                                          'G',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4285F4),
                                          ),
                                        ),
                                        onPressed: () => context
                                            .read<AuthBloc>()
                                            .add(AuthGoogleLoginRequested()),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: SocialLoginButton(
                                        label: t.otpLogin,
                                        icon: const Icon(
                                            Icons.smartphone_outlined,
                                            size: 18),
                                        onPressed: () =>
                                            context.push(AppRoutes.otpLogin),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      t.dontHaveAccount,
                                      style: AppTextStyles.body(locale)
                                          .copyWith(color: AppColors.fg3),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          context.push(AppRoutes.signup),
                                      child: Text(
                                        t.signup,
                                        style:
                                            AppTextStyles.body(locale).copyWith(
                                          color: AppColors.coralGoldDeep,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                const Attribution(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
