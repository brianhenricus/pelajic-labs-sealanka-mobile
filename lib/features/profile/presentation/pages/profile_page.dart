import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/attribution.dart';
import 'package:sea_lanka/core/widgets/harbour_picker_field.dart';
import 'package:sea_lanka/core/widgets/list_row.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/option_picker.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sea_lanka/features/profile/domain/entities/user_profile.dart';
import 'package:sea_lanka/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:sea_lanka/main.dart' show appLocale;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const ProfileRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) context.go(AppRoutes.login);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoaded) {
              return _ProfileContent(profile: state.profile);
            }
            if (state is ProfileError) {
              return _ErrorView(message: state.message);
            }
            return const _LoadingView();
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final UserProfile profile;
  const _ProfileContent({required this.profile});

  static const _languages = ['English', 'Sinhala', 'Tamil'];
  static const _languageCodes = {
    'English': 'en',
    'Sinhala': 'si',
    'Tamil': 'ta'
  };
  static const _unitsOptions = ['Metric', 'Imperial'];

  Future<void> _pickLanguage(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final selected = await showOptionPicker(context,
        title: t.languageLabel, options: _languages, current: profile.language);
    if (selected == null || !context.mounted) return;
    final code = _languageCodes[selected];
    if (code != null) appLocale.value = Locale(code);
    context
        .read<ProfileBloc>()
        .add(ProfileUpdateRequested({'language': selected}));
  }

  Future<void> _pickUnits(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final selected = await showOptionPicker(context,
        title: t.unitsLabel, options: _unitsOptions, current: profile.units);
    if (selected == null || !context.mounted) return;
    context
        .read<ProfileBloc>()
        .add(ProfileUpdateRequested({'units': selected}));
  }

  Future<void> _pickHomePort(BuildContext context) async {
    final selected =
        await showHarbourPicker(context, current: profile.homePort);
    if (selected == null || !context.mounted) return;
    context
        .read<ProfileBloc>()
        .add(ProfileUpdateRequested({'home_port': selected}));
  }

  void _showHelp(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.helpAndSupportTitle),
        content: Text(t.helpSupportContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text(t.okLabel)),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.aboutSeaLankaTitle),
        content: Text(t.aboutSeaLankaContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: Text(t.okLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(profile: profile),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SeaLankaCard(
                child: Row(
                  children: [
                    Expanded(
                        child: _Stat(
                            value: '${profile.totalTrips}',
                            label: t.tripsStatLabel)),
                    _divider(),
                    Expanded(
                        child: _Stat(
                            value: '${profile.totalCatch}',
                            label: t.catchStatLabel)),
                    _divider(),
                    Expanded(
                        child: _Stat(
                            value: profile.totalWeightKg.toStringAsFixed(0),
                            label: t.kgTotalLabel)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              SeaLankaCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    ListRow(
                      icon: Icons.workspace_premium_rounded,
                      title: t.manageSubscriptionLabel,
                      trailing: _value(context, profile.planName),
                      onTap: () => context.push(AppRoutes.subscription),
                    ),
                    ListRow(
                      icon: Icons.language_rounded,
                      title: t.languageLabel,
                      trailing: _value(context, profile.language),
                      onTap: () => _pickLanguage(context),
                    ),
                    ListRow(
                      icon: Icons.straighten_rounded,
                      title: t.unitsLabel,
                      trailing: _value(context, profile.units),
                      onTap: () => _pickUnits(context),
                    ),
                    ListRow(
                      icon: Icons.anchor_rounded,
                      title: t.homePortLabel,
                      trailing: _value(context, profile.homePort),
                      onTap: () => _pickHomePort(context),
                    ),
                    ListRow(
                      icon: Icons.help_outline_rounded,
                      title: t.helpAndSupportTitle,
                      onTap: () => _showHelp(context),
                    ),
                    ListRow(
                      icon: Icons.info_outline_rounded,
                      title: t.aboutLabel,
                      onTap: () => _showAbout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              SeaLankaButton(
                label: t.logOutLabel,
                variant: SeaLankaButtonVariant.outline,
                icon: Icons.logout_rounded,
                onPressed: () =>
                    context.read<AuthBloc>().add(AuthLogoutRequested()),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Attribution(),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppColors.borderLight);

  Widget _value(BuildContext context, String text) {
    final locale = Localizations.localeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppTextStyles.body(locale).copyWith(color: AppColors.fg3)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.fg3),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final UserProfile profile;
  const _Header({required this.profile});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    final memberSince = DateFormat('MMMM yyyy').format(profile.memberSince);
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xl),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.home),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  Text(t.profileTitle,
                      style: AppTextStyles.h3(locale)
                          .copyWith(color: Colors.white)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _Avatar(name: profile.name, avatarUrl: profile.avatarUrl),
              const SizedBox(height: AppSpacing.md),
              Text(profile.name,
                  style:
                      AppTextStyles.h2(locale).copyWith(color: Colors.white)),
              const SizedBox(height: 2),
              Text(t.memberSinceLabel(memberSince),
                  style: AppTextStyles.caption(locale)
                      .copyWith(color: AppColors.fgOnDark2)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _Pill(
                    label: profile.subscriptionActive
                        ? t.activeSubscriptionLabel
                        : t.inactiveLabel,
                    color: profile.subscriptionActive
                        ? AppColors.success
                        : AppColors.fg3,
                  ),
                  _Pill(label: profile.planName, color: AppColors.coralGold),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _Avatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.fishGradient,
            ),
            alignment: Alignment.center,
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(avatarUrl!,
                        width: 88, height: 88, fit: BoxFit.cover))
                : Text(initials.toUpperCase(),
                    style:
                        AppTextStyles.h1(locale).copyWith(color: Colors.white)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.coralGold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.midnightNavy, width: 2),
              ),
              child: const Icon(Icons.edit, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: AppTextStyles.caption(locale)
              .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.h2(locale).copyWith(color: AppColors.fg1)),
        const SizedBox(height: 2),
        Text(label,
            style:
                AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: const [
        SizedBox(height: AppSpacing.xl2),
        Center(child: LoadingShimmer(width: 88, height: 88, borderRadius: 44)),
        SizedBox(height: AppSpacing.base),
        Center(child: LoadingShimmer(width: 160, height: 20)),
        SizedBox(height: AppSpacing.xl),
        ShimmerCard(),
        SizedBox(height: AppSpacing.base),
        ShimmerCard(),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.fg3),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    AppTextStyles.body(locale).copyWith(color: AppColors.fg2)),
            const SizedBox(height: AppSpacing.base),
            SeaLankaButton(
              label: t.retry,
              fullWidth: false,
              onPressed: () =>
                  context.read<ProfileBloc>().add(const ProfileRequested()),
            ),
          ],
        ),
      ),
    );
  }
}
