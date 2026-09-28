import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/features/alerts/domain/entities/safety_alert.dart';
import 'package:sea_lanka/features/alerts/presentation/bloc/alerts_bloc.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AlertsBloc>().add(const AlertsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: BlocBuilder<AlertsBloc, AlertsState>(
        builder: (context, state) {
          if (state is AlertsLoaded) {
            return _AlertsContent(alerts: state.alerts);
          }
          if (state is AlertsError) {
            return _ErrorView(message: state.message);
          }
          return const _LoadingView();
        },
      ),
    );
  }
}

class _AlertsContent extends StatelessWidget {
  final List<SafetyAlert> alerts;
  const _AlertsContent({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final critical =
        alerts.where((a) => a.severity == AlertSeverity.critical).length;
    final warning = alerts
        .where((a) =>
            a.severity == AlertSeverity.high ||
            a.severity == AlertSeverity.medium)
        .length;
    final info = alerts.where((a) => a.severity == AlertSeverity.low).length;

    return Column(
      children: [
        _DangerHeader(activeCount: alerts.length),
        _SeverityStrip(critical: critical, warning: warning, info: info),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _AlertCard(alert: alerts[i]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Loading view
// ─────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DangerHeader(activeCount: 0),
        const _SeverityStrip(critical: 0, warning: 0, info: 0),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => const ShimmerCard(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Error view
// ─────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
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
              label: AppLocalizations.of(context)!.retryAction,
              fullWidth: false,
              onPressed: () =>
                  context.read<AlertsBloc>().add(const AlertsRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Danger header
// ─────────────────────────────────────────
class _DangerHeader extends StatelessWidget {
  final int activeCount;
  const _DangerHeader({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppSpacing.radiusXl)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.probLow2, AppColors.danger],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md,
                AppSpacing.base, AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.safetyAlertsTitle,
                          style: AppTextStyles.h1(locale)
                              .copyWith(color: AppColors.fgOnDark)),
                      const SizedBox(height: 2),
                      Text(l10n.activeAlertsSriLanka('$activeCount'),
                          style: AppTextStyles.caption(locale).copyWith(
                              color: Colors.white.withOpacity(0.85))),
                    ],
                  ),
                ),
                const DataStatusBadge(status: DataStatus.live),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Severity strip
// ─────────────────────────────────────────
class _SeverityStrip extends StatelessWidget {
  final int critical;
  final int warning;
  final int info;
  const _SeverityStrip(
      {required this.critical, required this.warning, required this.info});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.cardLight,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.base),
      child: Row(
        children: [
          _SeverityItem(
              count: critical, label: l10n.critical, color: AppColors.danger),
          _stripDivider(),
          _SeverityItem(
              count: warning, label: l10n.warning, color: AppColors.warning),
          _stripDivider(),
          _SeverityItem(count: info, label: l10n.info, color: AppColors.info),
        ],
      ),
    );
  }

  Widget _stripDivider() =>
      Container(width: 1, height: 44, color: AppColors.borderLight);
}

class _SeverityItem extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _SeverityItem(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$count',
                style: AppTextStyles.h3(locale).copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                )),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label.toUpperCase(),
              style: AppTextStyles.overline(locale).copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Alert card
// ─────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final SafetyAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final (color, icon, badge) = _severityStyle(context, alert.severity);

    return SeaLankaCard(
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title,
                        style: AppTextStyles.bodyL(locale).copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.fg1,
                        )),
                    if (alert.affectedArea != null)
                      Text(alert.affectedArea!,
                          style: AppTextStyles.caption(locale)
                              .copyWith(color: AppColors.fg3)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(badge.toUpperCase(),
                    style: AppTextStyles.overline(locale).copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(alert.description,
              style: AppTextStyles.body(locale)
                  .copyWith(color: AppColors.fg2)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: l10n.issuedAt(DateFormat('HH:mm').format(alert.issuedAt)),
                color: AppColors.fg2,
                background: AppColors.backgroundLight,
              ),
              if (alert.expiresAt != null)
                _MetaChip(
                  icon: Icons.timer_outlined,
                  label: l10n
                      .expiresAt(DateFormat('HH:mm').format(alert.expiresAt!)),
                  color: AppColors.deepSeaBlue,
                  background: AppColors.backgroundLight,
                ),
            ],
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _severityStyle(
      BuildContext context, AlertSeverity severity) {
    final l10n = AppLocalizations.of(context)!;
    return switch (severity) {
      AlertSeverity.critical =>
        (AppColors.danger, Icons.warning_rounded, l10n.severityUrgent),
      AlertSeverity.high =>
        (AppColors.warning, Icons.air_rounded, l10n.warning),
      AlertSeverity.medium =>
        (AppColors.warning, Icons.info_rounded, l10n.warning),
      AlertSeverity.low =>
        (AppColors.info, Icons.check_circle_rounded, l10n.info),
    };
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  const _MetaChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.background});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.caption(locale).copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}
