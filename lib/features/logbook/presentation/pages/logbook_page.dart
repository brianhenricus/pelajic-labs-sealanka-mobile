import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_fab.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_header.dart';
import 'package:dio/dio.dart';
import 'package:sea_lanka/features/logbook/data/datasources/logbook_remote_datasource.dart';
import 'package:sea_lanka/features/logbook/data/repositories/logbook_repository_impl.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';
import 'package:sea_lanka/features/logbook/domain/usecases/get_trips_usecase.dart';
import 'package:sea_lanka/features/logbook/presentation/bloc/logbook_bloc.dart';

class LogbookPage extends StatefulWidget {
  const LogbookPage({super.key});

  @override
  State<LogbookPage> createState() => _LogbookPageState();
}

class _LogbookPageState extends State<LogbookPage> {
  late final LogbookBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = LogbookBloc(
      getTrips: GetTripsUseCase(
        LogbookRepositoryImpl(
          remoteDataSource: LogbookRemoteDataSourceImpl(sl<Dio>()),
          networkInfo: sl<NetworkInfo>(),
        ),
      ),
    )..add(const TripsRequested());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: const _LogbookView(),
    );
  }
}

class _LogbookView extends StatefulWidget {
  const _LogbookView();

  @override
  State<_LogbookView> createState() => _LogbookViewState();
}

class _LogbookViewState extends State<_LogbookView> {
  int _filterIndex = 1; // default: This Month

  List<String> _filters(AppLocalizations l10n) => [
        l10n.thisWeek,
        l10n.thisMonth,
        l10n.thisYear,
        l10n.allTime,
      ];

  Future<void> _addTripThenRefresh(BuildContext context) async {
    final bloc = context.read<LogbookBloc>();
    await context.push(AppRoutes.addTrip);
    if (!mounted) return;
    bloc.add(const TripsRequested());
  }

  // Purely a display filter -- GET /logbook/trips already returns everything,
  // so this just narrows what's shown/summed, no extra network call.
  List<TripLog> _filteredTrips(List<TripLog> trips) {
    if (_filterIndex == 3) return trips; // All time
    final now = DateTime.now();
    final DateTime cutoff = switch (_filterIndex) {
      0 => now.subtract(Duration(days: now.weekday - 1)), // This week (Mon start)
      1 => DateTime(now.year, now.month, 1), // This month
      _ => DateTime(now.year, 1, 1), // This year
    };
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    return trips.where((t) => !t.date.isBefore(cutoffDay)).toList();
  }

  bool _exporting = false;

  Future<void> _export(List<TripLog> trips) async {
    if (trips.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await _buildLogbookPdf(trips);
      await Printing.sharePdf(bytes: bytes, filename: 'sealanka_logbook.pdf');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = _filters(l10n);
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: BlocBuilder<LogbookBloc, LogbookState>(
        builder: (context, state) {
          if (state is LogbookError) {
            return _ErrorView(message: state.message);
          }
          final bool isLoading = state is! LogbookLoaded;
          final List<TripLog> allTrips =
              state is LogbookLoaded ? state.trips : const [];
          final List<TripLog> trips = _filteredTrips(allTrips);

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SeaLankaHeader(
                  title: l10n.myLogbook,
                  subtitle: 'මගේ ලොග් පොත',
                  actions: [
                    GestureDetector(
                      onTap: (isLoading || _exporting)
                          ? null
                          : () => _export(trips),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: _exporting
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DataStatusBadge(status: DataStatus.live, detail: l10n.synced),
                  ],
                ),
              ),

              // Summary stats card — overlaps the header by less than the
              // card's own padding (AppSpacing.cardPadding = 16) so only
              // whitespace intrudes into the header's curved bottom edge,
              // never the stat numbers themselves. SeaLankaHeader's default
              // bottom padding is only 20 (not the 40 the home page's own
              // custom header reserves for this same overlap pattern), so
              // this needed a smaller offset than other overlapping cards
              // in the app -- was -28, clipping into the header.
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePadding),
                    child: _SummaryStatsBar(
                      isLoading: isLoading,
                      trips: trips,
                    ),
                  ),
                ),
              ),

              // Filter chips
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePadding,
                        vertical: AppSpacing.xs),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(filters.length, (i) {
                          final isSelected = i == _filterIndex;
                          return Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.sm),
                            child: _FilterChip(
                              label: filters[i],
                              selected: isSelected,
                              onTap: () => setState(() => _filterIndex = i),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),

              // Trip list
              if (isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.pagePadding,
                      AppSpacing.xs, AppSpacing.pagePadding, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: ShimmerCard(),
                      ),
                      childCount: 3,
                    ),
                  ),
                )
              else if (trips.isEmpty)
                SliverFillRemaining(
                    child: _EmptyState(noneAtAll: allTrips.isEmpty))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.xs,
                      AppSpacing.pagePadding,
                      96), // extra bottom for FAB
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _TripCard(
                          trip: trips[i],
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _TripDetailSheet(trip: trips[i]),
                          ),
                        ),
                      ),
                      childCount: trips.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: SeaLankaFab(
        icon: Icons.add_rounded,
        tooltip: l10n.addTripTooltip,
        onPressed: () => _addTripThenRefresh(context),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepSeaBlue : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? AppColors.deepSeaBlue : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption(locale).copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.fgOnDark : AppColors.fg2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Summary stats card
// ─────────────────────────────────────────
class _SummaryStatsBar extends StatelessWidget {
  final bool isLoading;
  final List<TripLog> trips;
  const _SummaryStatsBar({required this.isLoading, required this.trips});

  String _formatKg(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(1)}K';
    }
    return kg.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) {
      return SeaLankaCard(
        child: Row(
          children: [
            _StatCol(value: '-', label: l10n.totalTrips),
            const _StatDivider(),
            _StatCol(value: '-', label: l10n.kgCaught),
            const _StatDivider(),
            _StatCol(value: '-', label: l10n.bestDay),
          ],
        ),
      );
    }

    final totalTrips = trips.length;
    final totalKg = trips.fold<double>(0, (sum, t) => sum + t.totalCatchKg);

    String bestDay = '-';
    if (trips.isNotEmpty) {
      // Not trips.reduce(...): the repository hands back a List<TripLog>
      // whose runtime element type is actually TripLogModel (built via
      // .map().toList() in the datasource) -- reduce()'s combine callback
      // type-checks against that reified runtime type, not the declared
      // List<TripLog>, so a closure the compiler infers as
      // (TripLog,TripLog)=>TripLog fails at runtime ("not a subtype of
      // (TripLogModel,TripLogModel)=>TripLogModel"). A plain loop sidesteps
      // the generic-variance mismatch entirely. Real crash, only ever hit
      // once the list stopped being empty -- found while testing the first
      // real trip save.
      var best = trips.first;
      for (final t in trips) {
        if (t.totalCatchKg > best.totalCatchKg) best = t;
      }
      bestDay = DateFormat('MMM d').format(best.date);
    }

    return SeaLankaCard(
      child: Row(
        children: [
          _StatCol(value: '$totalTrips', label: l10n.totalTrips),
          const _StatDivider(),
          _StatCol(value: _formatKg(totalKg), label: l10n.kgCaught),
          const _StatDivider(),
          _StatCol(value: bestDay, label: l10n.bestDay),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value;
  final String label;
  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.h2(locale)
                  .copyWith(color: AppColors.deepSeaBlue)),
          const SizedBox(height: AppSpacing.xs),
          Text(label.toUpperCase(),
              style: AppTextStyles.overline(locale)
                  .copyWith(color: AppColors.fg3)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.borderLight,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

// ─────────────────────────────────────────
// Trip card
// ─────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final TripLog trip;
  final VoidCallback onTap;
  const _TripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final durationStr =
        '${trip.duration.inHours} h ${trip.duration.inMinutes.remainder(60)} m';
    final totalKg = trip.totalCatchKg;
    final dateStr = DateFormat('MMM d, yyyy').format(trip.date);

    return GestureDetector(
      onTap: onTap,
      child: SeaLankaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr,
                  style: AppTextStyles.bodyL(locale).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg1,
                  )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 12, color: AppColors.deepSeaBlue),
                    const SizedBox(width: 4),
                    Text(durationStr,
                        style: AppTextStyles.caption(locale).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepSeaBlue,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Location
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  size: 14, color: AppColors.coralGold),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(trip.location,
                    style: AppTextStyles.caption(locale)
                        .copyWith(color: AppColors.fg2)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Species chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: trip.catches
                .map((c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.set_meal_rounded,
                              size: 12, color: AppColors.deepSeaBlue),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${c.species} · ${c.weightKg.toStringAsFixed(1)} kg',
                            style: AppTextStyles.caption(locale).copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.fg1,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
          if (trip.photoUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _PhotoStrip(photoUrls: trip.photoUrls),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: AppSpacing.md),
          // Bottom stats
          Row(
            children: [
              _TotalStat(
                icon: Icons.inventory_2_rounded,
                value: '${totalKg.toStringAsFixed(1)} kg',
                label: l10n.catchLabel,
              ),
              if (trip.fuelLiters != null) ...[
                const SizedBox(width: AppSpacing.lg),
                _TotalStat(
                  icon: Icons.local_gas_station_outlined,
                  value: '${trip.fuelLiters!.toStringAsFixed(0)} L',
                  label: l10n.fuelLabel,
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Text(l10n.details,
                      style: AppTextStyles.caption(locale).copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.marineBlue,
                      )),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.marineBlue, size: 16),
                ],
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<String> photoUrls;
  const _PhotoStrip({required this.photoUrls});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final shown = photoUrls.take(3).toList();
    final extra = photoUrls.length - shown.length;
    return Row(
      children: [
        ...shown.map((url) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Container(
                  width: 64,
                  height: 52,
                  decoration: const BoxDecoration(gradient: AppColors.fishGradient),
                  child: Image.network(url,
                      width: 64,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_rounded,
                          color: AppColors.skyBlue,
                          size: 20)),
                ),
              ),
            )),
        if (extra > 0)
          Container(
            width: 64,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text('+$extra',
                style: AppTextStyles.bodyL(locale).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepSeaBlue,
                )),
          ),
      ],
    );
  }
}

class _TotalStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _TotalStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.deepSeaBlue),
        const SizedBox(width: AppSpacing.xs),
        Text(value,
            style: AppTextStyles.caption(locale).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.fg1,
            )),
        const SizedBox(width: 4),
        Text(label,
            style:
                AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool noneAtAll;
  const _EmptyState({required this.noneAtAll});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.set_meal_rounded,
              size: 72, color: AppColors.borderLight),
          const SizedBox(height: AppSpacing.base),
          Text(
              noneAtAll ? l10n.noTripsLoggedYet : l10n.noTripsInThisPeriod,
              style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg2)),
          const SizedBox(height: AppSpacing.sm),
          Text(
              noneAtAll
                  ? l10n.tapToRecordFirstCatch
                  : l10n.tryDifferentTimeFilter,
              style: AppTextStyles.body(locale)
                  .copyWith(color: AppColors.fg3)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Error state
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
                style: AppTextStyles.body(locale)
                    .copyWith(color: AppColors.fg2)),
            const SizedBox(height: AppSpacing.base),
            SeaLankaButton(
              label: AppLocalizations.of(context)!.retryAction,
              fullWidth: false,
              onPressed: () =>
                  context.read<LogbookBloc>().add(const TripsRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Trip detail sheet — full trip info behind "Details →" on the card:
// every catch (the card only shows a Wrap that can clip), every photo in a
// grid (the card strip caps at 3 + "+N"), notes, and fuel.
// ─────────────────────────────────────────
class _TripDetailSheet extends StatelessWidget {
  final TripLog trip;
  const _TripDetailSheet({required this.trip});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final durationStr =
        '${trip.duration.inHours}h ${trip.duration.inMinutes.remainder(60)}m';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
        boxShadow: AppShadows.sheet,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('MMMM d, yyyy').format(trip.date),
                      style: AppTextStyles.h2(locale).copyWith(color: AppColors.fg1)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 14, color: AppColors.coralGold),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(trip.location,
                            style: AppTextStyles.caption(locale)
                                .copyWith(color: AppColors.fg2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Row(
                    children: [
                      _StatTile(
                          icon: Icons.inventory_2_rounded,
                          value: '${trip.totalCatchKg.toStringAsFixed(1)} kg',
                          label: l10n.totalCatch),
                      const SizedBox(width: AppSpacing.sm),
                      _StatTile(
                          icon: Icons.schedule_rounded,
                          value: durationStr,
                          label: l10n.durationLabel),
                      const SizedBox(width: AppSpacing.sm),
                      _StatTile(
                          icon: Icons.local_gas_station_outlined,
                          value: trip.fuelLiters != null
                              ? '${trip.fuelLiters!.toStringAsFixed(1)} L'
                              : '',
                          label: l10n.fuelTileLabel),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.catches,
                      style: AppTextStyles.body(locale).copyWith(
                          color: AppColors.fg1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  ...trip.catches.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            const Icon(Icons.set_meal_rounded,
                                size: 14, color: AppColors.deepSeaBlue),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(c.species,
                                  style: AppTextStyles.body(locale)
                                      .copyWith(color: AppColors.fg1)),
                            ),
                            Text(
                                '${c.weightKg.toStringAsFixed(1)} kg · ${c.quantity} fish',
                                style: AppTextStyles.caption(locale)
                                    .copyWith(color: AppColors.fg3)),
                          ],
                        ),
                      )),
                  if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(l10n.notesLabel,
                        style: AppTextStyles.body(locale).copyWith(
                            color: AppColors.fg1, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(trip.notes!,
                        style: AppTextStyles.body(locale)
                            .copyWith(color: AppColors.fg2)),
                  ],
                  if (trip.photoUrls.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(l10n.photos,
                        style: AppTextStyles.body(locale).copyWith(
                            color: AppColors.fg1, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: trip.photoUrls.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: AppSpacing.sm,
                          mainAxisSpacing: AppSpacing.sm),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: Image.network(trip.photoUrls[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: AppColors.backgroundLight,
                                child: const Icon(Icons.image_rounded,
                                    color: AppColors.skyBlue))),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md + bottomInset),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.marineBlue, size: 20),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: AppTextStyles.body(locale).copyWith(color: AppColors.fg1)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PDF export — plain table, one row per trip, matches what's on screen
// (already filtered to the selected period). No photos: printing.sharePdf
// hands the file straight to the OS share sheet, keeping it small/fast
// rather than embedding every trip photo.
// ─────────────────────────────────────────
Future<Uint8List> _buildLogbookPdf(List<TripLog> trips) async {
  final doc = pw.Document();
  final dateFmt = DateFormat('MMM d, yyyy');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Text('Sea Lanka Fishing Logbook',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      ),
      build: (_) => [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.4),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(2.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell('Date', bold: true),
                _pdfCell('Location', bold: true),
                _pdfCell('Duration', bold: true),
                _pdfCell('Fuel (L)', bold: true),
                _pdfCell('Catches', bold: true),
              ],
            ),
            for (final t in trips)
              pw.TableRow(children: [
                _pdfCell(dateFmt.format(t.date)),
                _pdfCell(t.location),
                _pdfCell(
                    '${t.duration.inHours}h ${t.duration.inMinutes.remainder(60)}m'),
                _pdfCell(t.fuelLiters?.toStringAsFixed(1) ?? ''),
                _pdfCell(t.catches
                    .map((c) => '${c.species} ${c.weightKg.toStringAsFixed(1)}kg')
                    .join(', ')),
              ]),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
            'Total trips: ${trips.length}   ·   Total catch: '
            '${trips.fold<double>(0, (s, t) => s + t.totalCatchKg).toStringAsFixed(1)} kg',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
