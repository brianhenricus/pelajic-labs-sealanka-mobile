import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/harbour_picker_field.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/profile/presentation/bloc/profile_bloc.dart';

/// Mandatory post-Google-sign-in step: a Google account has no boat/
/// registration/harbour/fishing-type on file (nothing in the Google
/// identity token provides them, unlike the phone/password signup form
/// which collects them up front). Gated on [User.needsProfileCompletion]
/// in login_page.dart / splash_page.dart — the user cannot reach Home
/// until this is filled in, so there is deliberately no back button and
/// the hardware back gesture is blocked (see [PopScope] below).
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _boatNameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _harbourController = TextEditingController();
  final _fuelController = TextEditingController();
  final _speedController = TextEditingController();
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
    _boatNameController.dispose();
    _registrationController.dispose();
    _harbourController.dispose();
    _fuelController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  void _onSubmit(AppLocalizations t) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final fishingTypeLabels = [t.dayBoat, t.nightBoat, t.trawler, t.shore];
    context.read<ProfileBloc>().add(ProfileUpdateRequested({
          'boat_name': _boatNameController.text.trim(),
          'registration_no': _registrationController.text.trim(),
          'home_harbour': _harbourController.text.trim(),
          'fishing_type': fishingTypeLabels[_fishingTypeIndex],
          if (_selectedDistricts.isNotEmpty)
            'fishing_districts': _selectedDistricts.toList(),
          if (_fuelController.text.trim().isNotEmpty)
            'fuel_consumption_lph':
                double.tryParse(_fuelController.text.trim()),
          if (_speedController.text.trim().isNotEmpty)
            'cruising_speed_knots':
                double.tryParse(_speedController.text.trim()),
        }));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded && state.profile.profileComplete) {
            context.go(AppRoutes.subscription);
          } else if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.danger),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.directions_boat_rounded,
                          size: 48, color: AppColors.deepSeaBlue),
                      const SizedBox(height: AppSpacing.md),
                      Text(t.completeProfileTitle,
                          style: AppTextStyles.h1(locale)
                              .copyWith(color: AppColors.fg1)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        t.completeProfileSubtitle,
                        style: AppTextStyles.body(locale)
                            .copyWith(color: AppColors.fg3),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SlTextField(
                        controller: _boatNameController,
                        label: t.boatName,
                        hint: t.boatNameHint,
                        prefixIcon: Icons.directions_boat_outlined,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? t.requiredFieldValidation
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      SlTextField(
                        controller: _registrationController,
                        label: t.registrationNo,
                        hint: t.registrationNoHint,
                        prefixIcon: Icons.badge_outlined,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? t.requiredFieldValidation
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      HarbourPickerField(
                        controller: _harbourController,
                        label: t.homeHarbour,
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? t.requiredFieldValidation
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Text(t.fishingType,
                          style: AppTextStyles.caption(locale).copyWith(
                              color: AppColors.fg2,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.xs),
                      _FishingTypeChips(
                        selectedIndex: _fishingTypeIndex,
                        onSelected: (i) =>
                            setState(() => _fishingTypeIndex = i),
                        labels: [t.dayBoat, t.nightBoat, t.trawler, t.shore],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Text(t.fishingDistricts,
                          style: AppTextStyles.caption(locale).copyWith(
                              color: AppColors.fg2,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _districts.map((d) {
                          final isOn = _selectedDistricts.contains(d);
                          return GestureDetector(
                            onTap: () => setState(() {
                              isOn
                                  ? _selectedDistricts.remove(d)
                                  : _selectedDistricts.add(d);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: isOn
                                    ? AppColors.marineBlue.withOpacity(0.15)
                                    : AppColors.cardLight,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                                border: Border.all(
                                  color: isOn
                                      ? AppColors.marineBlue.withOpacity(0.4)
                                      : AppColors.borderLight,
                                ),
                              ),
                              child: Text(d,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isOn
                                        ? AppColors.marineBlue
                                        : AppColors.fg1,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(t.boatPerformanceOptional,
                          style: AppTextStyles.caption(locale).copyWith(
                              color: AppColors.fg2,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        t.boatPerformanceDescription,
                        style: AppTextStyles.caption(locale)
                            .copyWith(color: AppColors.fg3),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SlTextField(
                        controller: _fuelController,
                        label: t.fuelConsumptionLabel,
                        hint: t.egValueHint('12'),
                        prefixIcon: Icons.local_gas_station_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      SlTextField(
                        controller: _speedController,
                        label: t.cruisingSpeedLabel,
                        hint: t.egValueHint('8'),
                        prefixIcon: Icons.speed_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SeaLankaButton(
                        label: t.continueLabel,
                        variant: SeaLankaButtonVariant.cta,
                        icon: Icons.arrow_forward_rounded,
                        trailingIcon: true,
                        isLoading: state is ProfileLoading,
                        onPressed: () => _onSubmit(t),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isOn ? AppColors.deepSeaBlue : AppColors.cardLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color: isOn ? Colors.transparent : AppColors.borderLight),
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
