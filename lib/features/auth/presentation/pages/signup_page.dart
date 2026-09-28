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
import 'package:sea_lanka/core/widgets/harbour_picker_field.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sea_lanka/features/auth/presentation/widgets/auth_decor.dart';

enum _SignupStep { personal, boatInfo }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _boatNameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _harbourController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  _SignupStep _step = _SignupStep.personal;
  int _fishingTypeIndex = 0;
  final Set<String> _selectedDistricts = {};

  static const _districts = [
    'Negombo',
    'Colombo',
    'Trinco',
    'Galle',
    'Jaffna',
    'Batticaloa',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _boatNameController.dispose();
    _registrationController.dispose();
    _harbourController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (!_agreedToTerms) return;
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _step = _SignupStep.boatInfo);
    }
  }

  void _onSignup() {
    final t = AppLocalizations.of(context)!;
    final fishingTypeLabels = [t.dayBoat, t.nightBoat, t.trawler, t.shore];
    context.read<AuthBloc>().add(AuthSignupRequested(
          name: _nameController.text.trim(),
          phone: normalizePhoneOrEmail(_phoneController.text),
          password: _passwordController.text,
          boatName: _boatNameController.text.trim().isEmpty
              ? null
              : _boatNameController.text.trim(),
          registrationNo: _registrationController.text.trim().isEmpty
              ? null
              : _registrationController.text.trim(),
          homeHarbour: _harbourController.text.trim().isEmpty
              ? null
              : _harbourController.text.trim(),
          fishingType: fishingTypeLabels[_fishingTypeIndex],
          fishingDistricts:
              _selectedDistricts.isEmpty ? null : _selectedDistricts.toList(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // Every phone/password signup now needs OTP verification first
          // (mandatory, server-enforced) -- postAuthRoute sends them to
          // verify-phone, which itself lands on subscription/pricing next,
          // same destination signup used to go straight to.
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
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Hero — back button, logo, title, subtitle, language pills
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                          AppSpacing.sm, AppSpacing.pagePadding, AppSpacing.lg),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _BackButton(
                                onTap: () {
                                  if (_step == _SignupStep.boatInfo) {
                                    setState(
                                        () => _step = _SignupStep.personal);
                                  } else {
                                    context.pop();
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const AuthLogoMark(size: 80),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            t.createAccount,
                            style: AppTextStyles.h1(locale)
                                .copyWith(color: AppColors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.joinCommunity,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(locale)
                                .copyWith(color: AppColors.skyBlue),
                          ),
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
                            AppSpacing.lg,
                            AppSpacing.xl,
                            AppSpacing.lg +
                                MediaQuery.of(context).padding.bottom),
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _StepIndicator(step: _step, t: t),
                                const SizedBox(height: AppSpacing.lg),
                                if (_step == _SignupStep.personal)
                                  ..._buildPersonalStep(locale, t)
                                else
                                  ..._buildBoatInfoStep(locale, t),
                                const SizedBox(height: AppSpacing.base),
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

  List<Widget> _buildPersonalStep(Locale locale, AppLocalizations t) {
    return [
      SlTextField(
        controller: _nameController,
        label: t.fullName,
        hint: 'Kumara Perera',
        prefixIcon: Icons.person_outline_rounded,
        validator: (v) =>
            (v?.isEmpty ?? true) ? t.enterYourNameValidation : null,
      ),
      const SizedBox(height: AppSpacing.base),
      SlTextField(
        controller: _phoneController,
        label: t.phoneNumber,
        hint: '77 123 4567',
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (v) => (v?.isEmpty ?? true) ? t.enterPhoneValidation : null,
      ),
      const SizedBox(height: AppSpacing.base),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t.emailAddress,
              style: AppTextStyles.caption(locale)
                  .copyWith(color: AppColors.fg2, fontWeight: FontWeight.w600)),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(t.optional,
                style: AppTextStyles.caption(locale)
                    .copyWith(color: AppColors.fg3, fontSize: 10)),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      SlTextField(
        controller: _emailController,
        hint: 'kumara@example.com',
        prefixIcon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: AppSpacing.base),
      SlTextField(
        controller: _passwordController,
        label: t.password,
        hint: t.createStrongPasswordHint,
        prefixIcon: Icons.lock_outline_rounded,
        obscureText: _obscurePassword,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        validator: (v) =>
            (v?.length ?? 0) < 6 ? t.minPasswordLengthValidation : null,
      ),
      const SizedBox(height: AppSpacing.base),
      SlTextField(
        controller: _confirmController,
        label: t.confirmPassword,
        hint: t.repeatPasswordHint,
        prefixIcon: Icons.lock_outline_rounded,
        obscureText: _obscurePassword,
        validator: (v) => v != _passwordController.text
            ? t.passwordsDoNotMatchValidation
            : null,
      ),
      const SizedBox(height: AppSpacing.base),
      Text(t.fishingType,
          style: AppTextStyles.caption(locale)
              .copyWith(color: AppColors.fg2, fontWeight: FontWeight.w600)),
      const SizedBox(height: AppSpacing.xs),
      _FishingTypeChips(
        selectedIndex: _fishingTypeIndex,
        onSelected: (i) => setState(() => _fishingTypeIndex = i),
        labels: [t.dayBoat, t.nightBoat, t.trawler, t.shore],
      ),
      const SizedBox(height: AppSpacing.base),
      _TermsRow(
        agreed: _agreedToTerms,
        onChanged: (v) => setState(() => _agreedToTerms = v),
        locale: locale,
        t: t,
      ),
      const SizedBox(height: AppSpacing.base),
      SeaLankaButton(
        label: t.continueLabel,
        variant: SeaLankaButtonVariant.cta,
        icon: Icons.arrow_forward_rounded,
        trailingIcon: true,
        onPressed: _agreedToTerms ? _onContinue : null,
      ),
      const SizedBox(height: AppSpacing.base),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            t.alreadyHaveAccount,
            style: AppTextStyles.body(locale).copyWith(color: AppColors.fg3),
          ),
          GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              t.login,
              style: AppTextStyles.body(locale).copyWith(
                color: AppColors.coralGoldDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildBoatInfoStep(Locale locale, AppLocalizations t) {
    return [
      Text(t.boatInformation,
          style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg1)),
      const SizedBox(height: AppSpacing.base),
      SlTextField(
        controller: _boatNameController,
        label: t.boatName,
        hint: 'Sundara Putha',
        prefixIcon: Icons.directions_boat_outlined,
      ),
      const SizedBox(height: AppSpacing.base),
      SlTextField(
        controller: _registrationController,
        label: t.registrationNo,
        hint: 'CLB-1234',
        prefixIcon: Icons.badge_outlined,
      ),
      const SizedBox(height: AppSpacing.base),
      HarbourPickerField(
        controller: _harbourController,
        label: t.homeHarbour,
      ),
      const SizedBox(height: AppSpacing.base),
      Text(t.fishingDistricts,
          style: AppTextStyles.caption(locale)
              .copyWith(color: AppColors.fg2, fontWeight: FontWeight.w600)),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _districts.map((d) {
          final isOn = _selectedDistricts.contains(d);
          return GestureDetector(
            onTap: () => setState(() {
              isOn ? _selectedDistricts.remove(d) : _selectedDistricts.add(d);
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isOn
                    ? AppColors.marineBlue.withOpacity(0.15)
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: isOn
                      ? AppColors.marineBlue.withOpacity(0.4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                d,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOn ? AppColors.marineBlue : AppColors.fg1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: AppSpacing.lg),
      BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return SeaLankaButton(
            label: t.createAccount,
            variant: SeaLankaButtonVariant.cta,
            isLoading: state is AuthLoading,
            onPressed: _onSignup,
          );
        },
      ),
    ];
  }
}

class _StepIndicator extends StatelessWidget {
  final _SignupStep step;
  final AppLocalizations t;
  const _StepIndicator({required this.step, required this.t});

  @override
  Widget build(BuildContext context) {
    final stepIndex = step == _SignupStep.personal ? 0 : 1;
    return Row(
      children: [
        _StepPill(
            number: 1,
            label: t.stepPersonal,
            state: stepIndex == 0 ? _PillState.active : _PillState.done),
        _StepLine(done: stepIndex > 0),
        _StepPill(
            number: 2,
            label: t.stepBoatInfo,
            state: stepIndex == 1 ? _PillState.active : _PillState.upcoming),
        _StepLine(done: false),
        _StepPill(number: 3, label: t.stepDone, state: _PillState.upcoming),
      ],
    );
  }
}

enum _PillState { active, done, upcoming }

class _StepPill extends StatelessWidget {
  final int number;
  final String label;
  final _PillState state;
  const _StepPill(
      {required this.number, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (state) {
      _PillState.active => AppColors.deepSeaBlue,
      _PillState.done => AppColors.success,
      _PillState.upcoming => AppColors.borderLight,
    };
    final Color fg = switch (state) {
      _PillState.active || _PillState.done => Colors.white,
      _PillState.upcoming => AppColors.fg3,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == _PillState.done)
            const Icon(Icons.check_rounded, color: Colors.white, size: 13)
          else
            Text('$number',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: done ? AppColors.success : AppColors.borderLight,
      ),
    );
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

/// Fishing type selector chips — matches `.fchip` in signup.html.
class _FishingTypeChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  const _FishingTypeChips({
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final isOn = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isOn ? AppColors.deepSeaBlue : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOn ? Colors.white : AppColors.fg1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Terms-of-service checkbox row with embedded links — matches `.terms-row`.
class _TermsRow extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;
  final Locale locale;
  final AppLocalizations t;

  const _TermsRow({
    required this.agreed,
    required this.onChanged,
    required this.locale,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!agreed),
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: agreed ? AppColors.coralGold : AppColors.borderLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: agreed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.caption(locale).copyWith(
                color: AppColors.fg2,
                fontSize: 12,
                height: 1.5,
              ),
              children: [
                TextSpan(text: t.termsPrefix),
                TextSpan(
                  text: t.termsOfService,
                  style: const TextStyle(
                    color: AppColors.marineBlue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: t.termsAnd),
                TextSpan(
                  text: t.privacyPolicy,
                  style: const TextStyle(
                    color: AppColors.marineBlue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: t.termsSuffix),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
