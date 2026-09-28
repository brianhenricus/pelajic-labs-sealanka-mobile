import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/attribution.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:sea_lanka/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:sea_lanka/features/subscription/domain/entities/subscription_plan.dart';
import 'package:sea_lanka/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:sea_lanka/features/subscription/domain/usecases/get_plans_usecase.dart';
import 'package:sea_lanka/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:sea_lanka/features/subscription/presentation/widgets/payment_details_sheet.dart';

class SubscriptionTiersPage extends StatelessWidget {
  const SubscriptionTiersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = SubscriptionRepositoryImpl(
      remoteDataSource: SubscriptionRemoteDataSourceImpl(sl()),
      networkInfo: sl(),
    );
    return BlocProvider(
      create: (_) => SubscriptionBloc(getPlans: GetPlansUseCase(repository)),
      child: _SubscriptionTiersView(repository: repository),
    );
  }
}

class _SubscriptionTiersView extends StatefulWidget {
  final SubscriptionRepository repository;
  const _SubscriptionTiersView({required this.repository});

  @override
  State<_SubscriptionTiersView> createState() => _SubscriptionTiersViewState();
}

class _SubscriptionTiersViewState extends State<_SubscriptionTiersView> {
  int _selectedIndex = 1;
  bool _isSubscribing = false;
  MySubscription? _mySubscription;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionBloc>().add(const PlansRequested());
    _loadMySubscription();
  }

  Future<void> _loadMySubscription() async {
    final result = await widget.repository.getMySubscription();
    if (!mounted) return;
    result.fold((_) {}, (sub) {
      setState(() => _mySubscription = sub);
      // Opens on the user's actual current plan rather than a fixed
      // default index, when the plan list has already loaded.
      final blocState = context.read<SubscriptionBloc>().state;
      if (blocState is SubscriptionLoaded) {
        final i = blocState.plans.indexWhere((p) => p.id == sub.planId);
        if (i != -1) setState(() => _selectedIndex = i);
      }
    });
  }

  Future<void> _subscribe(SubscriptionPlan plan, bool isTrialActive) async {
    final current = _mySubscription;
    // Already on this exact plan -- nothing to do.
    if (current != null && current.planId == plan.id) return;

    if (plan.isFree) {
      final result = await widget.repository.subscribe(plan.id);
      if (!mounted) return;
      result.fold(
        (failure) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message))),
        (_) => context.go(AppRoutes.home),
      );
      return;
    }

    // Trial covers every plan for free -- no payment step needed while
    // it's still active, matching _PriceLabel's own "Free during beta"
    // display for the same condition.
    String? paymentMethodToken;
    if (!isTrialActive) {
      paymentMethodToken = await showPaymentDetailsSheet(
        context: context,
        planName: plan.name,
        priceLabel: AppLocalizations.of(context)!
            .priceLkrLabel(plan.priceMonthly.toStringAsFixed(0)),
      );
      if (paymentMethodToken == null) return; // sheet dismissed, not confirmed
      if (!mounted) return;
    }

    setState(() => _isSubscribing = true);
    final result = await widget.repository
        .subscribe(plan.id, paymentMethodToken: paymentMethodToken);
    if (!mounted) return;
    setState(() => _isSubscribing = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        _loadMySubscription();
        context.go(AppRoutes.home);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Dark header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          _CircleIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => context.go(AppRoutes.home),
                          )
                        else
                          const SizedBox(width: 40),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.coralGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x59F4A030),
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(t.chooseYourPlanTitle,
                        style: AppTextStyles.h1(locale)
                            .copyWith(color: AppColors.fgOnDark)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(t.subscriptionSubtitle,
                        style: AppTextStyles.body(locale)
                            .copyWith(color: AppColors.skyBlue)),
                    BlocBuilder<SubscriptionBloc, SubscriptionState>(
                      builder: (context, state) {
                        if (state is! SubscriptionLoaded ||
                            !state.isTrialActive) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.coralGold.withOpacity(0.16),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Text(
                              t.betaTrialBanner(DateFormat('MMM d, yyyy')
                                  .format(state.trialEndsAt)),
                              style: AppTextStyles.caption(locale).copyWith(
                                  color: AppColors.coralGold,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_mySubscription != null && !_mySubscription!.isFree)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: (_mySubscription!.inGrace
                                    ? AppColors.danger
                                    : AppColors.marineBlue)
                                .withOpacity(0.16),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            _mySubscription!.inGrace
                                ? t.paymentOverdueLabel(
                                    '${_mySubscription!.graceDaysLeft ?? 0}')
                                : _mySubscription!.renewsAt != null
                                    ? '${t.yourCurrentPlanLabel(_mySubscription!.planName)} · ${t.renewsOnLabel(DateFormat('MMM d, yyyy').format(_mySubscription!.renewsAt!))}'
                                    : t.yourCurrentPlanLabel(
                                        _mySubscription!.planName),
                            style: AppTextStyles.caption(locale).copyWith(
                                color: _mySubscription!.inGrace
                                    ? AppColors.danger
                                    : AppColors.marineBlue,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Cards sheet
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.radiusXl)),
                  ),
                  child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
                    builder: (context, state) {
                      if (state is SubscriptionError) {
                        return _ErrorView(message: state.message);
                      }
                      if (state is SubscriptionLoaded) {
                        return _PlansContent(
                          plans: state.plans,
                          selectedIndex: _selectedIndex,
                          onSelect: (i) => setState(() => _selectedIndex = i),
                          isSubscribing: _isSubscribing,
                          onSubscribe: (plan) =>
                              _subscribe(plan, state.isTrialActive),
                          isTrialActive: state.isTrialActive,
                          currentPlanId: _mySubscription?.planId,
                        );
                      }
                      return const _LoadingView();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlansContent extends StatelessWidget {
  final List<SubscriptionPlan> plans;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isSubscribing;
  final ValueChanged<SubscriptionPlan> onSubscribe;
  final bool isTrialActive;
  final String? currentPlanId;

  const _PlansContent({
    required this.plans,
    required this.selectedIndex,
    required this.onSelect,
    required this.isSubscribing,
    required this.onSubscribe,
    required this.isTrialActive,
    required this.currentPlanId,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    final safeIndex =
        plans.isEmpty ? 0 : selectedIndex.clamp(0, plans.length - 1);
    final selected = plans.isEmpty ? null : plans[safeIndex];
    final isCurrentSelected = selected != null && currentPlanId == selected.id;
    // Already on a paid plan and switching to a different paid one, vs a
    // first-time subscribe -- "Change plan" reads correctly either way,
    // "Subscribe" would be misleading once there's already an active plan.
    final isChangingPlan = !isCurrentSelected &&
        currentPlanId != null &&
        currentPlanId != 'free' &&
        selected != null &&
        !selected.isFree;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        children: [
          ...List.generate(
            plans.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _PlanCard(
                plan: plans[i],
                isSelected: safeIndex == i,
                onTap: () => onSelect(i),
                isTrialActive: isTrialActive,
                isCurrentPlan: currentPlanId == plans[i].id,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selected != null)
            SeaLankaButton(
              label: isCurrentSelected
                  ? t.currentPlanBadge
                  : selected.isFree || isTrialActive
                      ? t.continueFreeLabel
                      : isChangingPlan
                          ? t.changePlanLabel(
                              selected.priceMonthly.toStringAsFixed(0))
                          : t.subscribeLabel(
                              selected.priceMonthly.toStringAsFixed(0)),
              variant: SeaLankaButtonVariant.cta,
              isLoading: isSubscribing,
              onPressed: (isSubscribing || isCurrentSelected)
                  ? null
                  : () => onSubscribe(selected),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(t.cancelAnytimeNote,
              style:
                  AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
          const SizedBox(height: AppSpacing.lg),
          const Attribution(),
          const SizedBox(height: AppSpacing.base),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, color: AppColors.fgOnDark, size: 20),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isTrialActive;
  final bool isCurrentPlan;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.isTrialActive,
    required this.isCurrentPlan,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
              color: isSelected ? AppColors.coralGold : Colors.transparent,
              width: 2,
            ),
          ),
          child: SeaLankaCard(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(plan.name,
                          style: AppTextStyles.h2(locale)
                              .copyWith(color: AppColors.fg1)),
                    ),
                    _PriceLabel(plan: plan, isTrialActive: isTrialActive),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...plan.features.map((f) => _FeatureRow(
                      label: f,
                      selected: isSelected,
                    )),
              ],
            ),
          ),
        ),
        if (plan.isPopular)
          Positioned(
            top: -10,
            left: AppSpacing.base,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.coralGold,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(t.mostPopularBadge,
                  style: AppTextStyles.overline(locale).copyWith(
                    color: AppColors.fgOnDark,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
        if (isCurrentPlan)
          Positioned(
            top: -10,
            right: AppSpacing.base,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(t.currentPlanBadge,
                  style: AppTextStyles.overline(locale).copyWith(
                    color: AppColors.fgOnDark,
                    fontWeight: FontWeight.w800,
                  )),
            ),
          ),
      ],
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isTrialActive;
  const _PriceLabel({required this.plan, required this.isTrialActive});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    if (plan.isFree) {
      return Text(t.freeLabel,
          style: AppTextStyles.h2(locale)
              .copyWith(color: AppColors.success, fontWeight: FontWeight.w800));
    }
    // During the beta trial every plan is free -- showing a real LKR price
    // here would contradict the trial banner above and the "Continue free"
    // button below.
    if (isTrialActive) {
      return Text(t.freeDuringTrialLabel,
          style: AppTextStyles.h2(locale)
              .copyWith(color: AppColors.success, fontWeight: FontWeight.w800));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.priceLkrLabel(plan.priceMonthly.toStringAsFixed(0)),
            style: AppTextStyles.h2(locale).copyWith(
              color: AppColors.marineBlue,
              fontWeight: FontWeight.w800,
            )),
        Text(t.perMonthSuffix,
            style:
                AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final bool selected;
  const _FeatureRow({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16,
              color: selected ? AppColors.coralGold : AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style:
                    AppTextStyles.body(locale).copyWith(color: AppColors.fg2)),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: const [
        ShimmerCard(),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(),
        SizedBox(height: AppSpacing.md),
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
                  context.read<SubscriptionBloc>().add(const PlansRequested()),
            ),
          ],
        ),
      ),
    );
  }
}
