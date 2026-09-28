import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/section_title.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';
import 'package:sea_lanka/features/ocean/presentation/bloc/ocean_bloc.dart';
import 'package:sea_lanka/features/ocean/presentation/pages/ocean_current_page.dart';

class TideGraphPage extends StatelessWidget {
  const TideGraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createOceanBloc(),
      child: const _TideGraphView(),
    );
  }
}

class _TideGraphView extends StatefulWidget {
  const _TideGraphView();

  @override
  State<_TideGraphView> createState() => _TideGraphViewState();
}

class _TideGraphViewState extends State<_TideGraphView> {
  @override
  void initState() {
    super.initState();
    _requestData();
  }

  Future<void> _requestData() async {
    final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
    if (!mounted) return;
    context.read<OceanBloc>().add(OceanRequested(lat: lat, lon: lon));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header()),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SectionTitle(title: AppLocalizations.of(context)!.todaysTideTitle),
                const SizedBox(height: AppSpacing.md),
                BlocBuilder<OceanBloc, OceanState>(
                  builder: (context, state) {
                    if (state is OceanLoaded) {
                      return _TideContent(tides: state.tides);
                    }
                    if (state is OceanError) {
                      return _ErrorCard(message: state.message, onRetry: _requestData);
                    }
                    return const _LoadingContent();
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TideContent extends StatelessWidget {
  final List<TidePrediction> tides;
  const _TideContent({required this.tides});

  List<FlSpot> _spots() => tides
      .map((t) => FlSpot(
            t.time.hour + t.time.minute / 60.0,
            t.heightM,
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final spots = _spots();
    final heights = tides.map((t) => t.heightM).toList();
    final maxH = heights.isEmpty
        ? 2.0
        : heights.reduce((a, b) => a > b ? a : b);
    final minH = heights.isEmpty
        ? 0.0
        : heights.reduce((a, b) => a < b ? a : b);
    final range = (maxH - minH);
    final highs = tides.where((t) => t.isHighTide).toList();
    final nextHigh = highs.isEmpty
        ? '--:--'
        : DateFormat('HH:mm').format(highs.first.time);

    return Column(
      children: [
        SeaLankaCard(
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.borderLight,
                    strokeWidth: 0.6,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 0.5,
                      getTitlesWidget: (val, _) => Text(
                        '${val.toStringAsFixed(1)} m',
                        style: AppTextStyles.overline(locale)
                            .copyWith(color: AppColors.fg3),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 6,
                      getTitlesWidget: (val, _) {
                        final h = val.toInt();
                        if (h % 6 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: AppTextStyles.overline(locale)
                                .copyWith(color: AppColors.fg3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.marineBlue,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.marineBlue.withOpacity(0.3),
                          AppColors.marineBlue.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minX: 0,
                maxX: 24,
                minY: 0,
                maxY: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: l10n.tidalRangeLabel,
                    value: '${range.toStringAsFixed(1)} m')),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: _StatCard(
                    label: l10n.nextHighLabel,
                    value: nextHigh,
                    valueColor: AppColors.deepSeaBlue)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
                child: _StatCard(
                    label: l10n.tidesCountLabel,
                    value: '${tides.length}')),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: SectionTitle(title: l10n.tideEventsTitle),
        ),
        const SizedBox(height: AppSpacing.md),
        ...tides.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TideEventRow(
                isHigh: e.isHighTide,
                time: DateFormat('HH:mm').format(e.time),
                height: e.heightM.toStringAsFixed(2),
              ),
            )),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SeaLankaCard(child: SizedBox(height: 220, child: ShimmerCard())),
        SizedBox(height: AppSpacing.base),
        ShimmerCard(),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SeaLankaCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.body(locale).copyWith(color: AppColors.fg2)),
          const SizedBox(height: AppSpacing.base),
          SeaLankaButton(
            label: AppLocalizations.of(context)!.retry,
            fullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm,
              AppSpacing.base, AppSpacing.lg),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.almanacOcean),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(AppLocalizations.of(context)!.tidePredictionsTitle,
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fgOnDark)),
              ),
              const DataStatusBadge(status: DataStatus.live),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCard({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SeaLankaCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.overline(locale)
                  .copyWith(color: AppColors.fg3)),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: AppTextStyles.h3(locale)
                  .copyWith(color: valueColor ?? AppColors.fg1)),
        ],
      ),
    );
  }
}

class _TideEventRow extends StatelessWidget {
  final bool isHigh;
  final String time;
  final String height;
  const _TideEventRow(
      {required this.isHigh, required this.time, required this.height});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final accent = isHigh ? AppColors.marineBlue : AppColors.teal;
    return SeaLankaCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              isHigh
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isHigh ? AppLocalizations.of(context)!.highTide : AppLocalizations.of(context)!.lowTideLabel,
                    style: AppTextStyles.bodyL(locale)
                        .copyWith(color: AppColors.fg1)),
                const SizedBox(height: 2),
                Text(time,
                    style: AppTextStyles.caption(locale)
                        .copyWith(color: AppColors.fg3)),
              ],
            ),
          ),
          Text('$height m',
              style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg1)),
        ],
      ),
    );
  }
}
