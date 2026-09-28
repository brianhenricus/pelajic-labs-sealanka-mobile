import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/core/network/vector_grid_datasource.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/particle_flow_layer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/selected_location_marker.dart';
import 'package:sea_lanka/core/widgets/sl_segmented.dart';
import 'package:sea_lanka/features/ocean/data/datasources/ocean_remote_datasource.dart';
import 'package:sea_lanka/features/ocean/data/repositories/ocean_repository_impl.dart';
import 'package:sea_lanka/features/ocean/domain/entities/ocean_current.dart';
import 'package:sea_lanka/features/ocean/domain/entities/tide_prediction.dart';
import 'package:sea_lanka/features/ocean/domain/usecases/get_ocean_current_usecase.dart';
import 'package:sea_lanka/features/ocean/domain/usecases/get_tides_usecase.dart';
import 'package:sea_lanka/features/ocean/presentation/bloc/ocean_bloc.dart';
import 'package:sea_lanka/core/widgets/speed_tiers.dart';

// Matches sealanka-be's ingestion bbox (ocean_source.py).
const double _kBboxSouth = -2,
    _kBboxNorth = 18,
    _kBboxWest = 68,
    _kBboxEast = 92;

OceanBloc createOceanBloc() {
  final remoteDataSource = OceanRemoteDataSourceImpl(sl<Dio>());
  final repository = OceanRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: sl<NetworkInfo>(),
  );
  return OceanBloc(
    getCurrent: GetOceanCurrentUseCase(repository),
    getTides: GetTidesUseCase(repository),
  );
}

String compassFromDeg(double deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final idx = (((deg % 360) + 22.5) ~/ 45) % 8;
  return dirs[idx];
}

class OceanCurrentPage extends StatelessWidget {
  const OceanCurrentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createOceanBloc(),
      child: const _OceanCurrentView(),
    );
  }
}

class _OceanCurrentView extends StatefulWidget {
  const _OceanCurrentView();

  @override
  State<_OceanCurrentView> createState() => _OceanCurrentViewState();
}

class _OceanCurrentViewState extends State<_OceanCurrentView> {
  int _tab = 0; // 0 = Current map, 1 = Tide graph
  List<List<double>> _currentsGrid = const [];
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _requestData();
    _loadGrid();
  }

  Future<void> _requestData() async {
    final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
    if (!mounted) return;
    setState(() => _selected = LatLng(lat, lon));
    context.read<OceanBloc>().add(OceanRequested(lat: lat, lon: lon));
  }

  /// Nullschool-style "tap a point to see its details".
  Future<void> _onMapTap(LatLng point) async {
    setState(() => _selected = point);
    context
        .read<OceanBloc>()
        .add(OceanRequested(lat: point.latitude, lon: point.longitude));
  }

  /// Retries at whichever point is currently selected -- falls back to a
  /// fresh device-location request if nothing's been selected yet. Used by
  /// the Tide graph tab's Retry button (previously a no-op, see
  /// _TideGraphTab), which shares this same OceanBloc/point rather than
  /// running its own separate fetch.
  void _retryAtSelected() {
    if (_selected != null) {
      context.read<OceanBloc>().add(
          OceanRequested(lat: _selected!.latitude, lon: _selected!.longitude));
    } else {
      _requestData();
    }
  }

  Future<void> _loadGrid() async {
    final grid =
        await fetchVectorGrid(sl<Dio>(), ApiEndpoints.oceanCurrentsGrid);
    if (mounted) setState(() => _currentsGrid = grid);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.home),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!.oceanCurrentsTidesTitle,
                        style: AppTextStyles.h3(locale)
                            .copyWith(color: AppColors.fgOnDark)),
                  ),
                  const DataStatusBadge(status: DataStatus.live),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md,
                  AppSpacing.base, AppSpacing.sm),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: SlSegmented(
                segments: [
                  AppLocalizations.of(context)!.currentMapTabLabel,
                  AppLocalizations.of(context)!.tideGraphTabLabel,
                ],
                selectedIndex: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _CurrentMapTab(
                      grid: _currentsGrid,
                      selected: _selected,
                      onMapTap: _onMapTap,
                    )
                  : _TideGraphTab(onRetry: _retryAtSelected),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen nullschool-style particle-flow map + tap-to-query bottom-
/// left detail card, matching the "Current map" mockup.
class _CurrentMapTab extends StatelessWidget {
  final List<List<double>> grid;
  final LatLng? selected;
  final ValueChanged<LatLng> onMapTap;
  const _CurrentMapTab(
      {required this.grid, required this.selected, required this.onMapTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(8.5, 80.7),
                initialZoom: 5.8,
                minZoom: 4,
                maxZoom: 9,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, point) => onMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pelajiclabs.sea_lanka',
                ),
                Container(color: Colors.black.withOpacity(0.55)),
                if (grid.isNotEmpty)
                  ParticleFlowLayer(
                    vectorPoints: grid,
                    // Matches sealanka-be's miamicurrents ingestion
                    // (0.2 degree native grid, see ocean_service.py).
                    gridStep: 0.2,
                    south: _kBboxSouth,
                    north: _kBboxNorth,
                    west: _kBboxWest,
                    east: _kBboxEast,
                    speedTiers: kCurrentSpeedTiers,
                    // Geostrophic currents here run ~0.1-0.5 m/s vs wind's
                    // several m/s -- boost the pace so the flow reads as
                    // clearly as the wind map instead of near-static dots.
                    speedMultiplier: 12.0,
                    // nullschool's currents view reads as dense, continuous
                    // flowing strands, not scattered dashes -- much longer
                    // trails (more, closer-together sample points so the
                    // curve reads smooth) and far more particles than the
                    // sparse default get closer to that look over this bbox.
                    trailLength: 26,
                    trailIntervalMs: 45.0,
                    particleCount: 2000,
                    strokeWidth: 1.1,
                  ),
                if (selected != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: selected!,
                      width: 22,
                      height: 22,
                      child: const SelectedLocationDot(),
                    ),
                  ]),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.base,
            right: AppSpacing.base,
            child: SpeedLegend(title: l10n.currentSpeedUnitLabel, tiers: kCurrentSpeedTiers),
          ),
          Positioned(
            left: AppSpacing.base,
            bottom: AppSpacing.base,
            right: AppSpacing.base,
            child: BlocBuilder<OceanBloc, OceanState>(
              builder: (context, state) {
                if (state is OceanLoaded) {
                  return _CurrentDetailCard(current: state.current);
                }
                if (state is OceanError) {
                  return const SizedBox.shrink();
                }
                return const SizedBox(
                  height: 56,
                  child: LoadingShimmer(
                      width: 180,
                      height: 56,
                      borderRadius: AppSpacing.radiusMd),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact bottom-left overlay card — matches the mockup's "0.6 m/s / SSW
/// SURFACE CURRENT / 28°C sea temp" callout for the tapped/current point.
class _CurrentDetailCard extends StatelessWidget {
  final OceanCurrent current;
  const _CurrentDetailCard({required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compass = compassFromDeg(current.directionDeg);
    final speedMs = current.speedKnots * 0.514444;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${speedMs.toStringAsFixed(1)} m/s',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text(l10n.surfaceCurrentLabel(compass),
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ],
          ),
          if (current.seaSurfaceTempC != null) ...[
            const SizedBox(width: AppSpacing.base),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.18),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                  l10n.seaTempValueLabel(
                      current.seaSurfaceTempC!.toStringAsFixed(0)),
                  style: const TextStyle(
                      color: AppColors.teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tide graph tab — 10-day tide curve, today's extremes with LOW/HIGH
/// badges, and tidal range/next high/salinity stat tiles.
class _TideGraphTab extends StatelessWidget {
  final VoidCallback onRetry;
  const _TideGraphTab({required this.onRetry});

  // OceanBloc already fetches tides alongside currents on load (see
  // OceanRequested's handler) -- no separate request needed on entry, just
  // render whatever's already in state. onRetry (from the parent) re-fires
  // that same request when the user taps Retry on an error.

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: BlocBuilder<OceanBloc, OceanState>(
        builder: (context, state) {
          if (state is OceanLoaded) {
            return _TideContent(tides: state.tides);
          }
          if (state is OceanError) {
            return _ErrorCard(message: state.message, onRetry: onRetry);
          }
          return const _LoadingContent();
        },
      ),
    );
  }
}

class _TideContent extends StatelessWidget {
  final List<TidePrediction> tides;
  const _TideContent({required this.tides});

  @override
  Widget build(BuildContext context) {
    // Tide predictions only exist near the 16 coastal reference stations
    // (see sealanka-be's tide_reference_points) -- a point far from all of
    // them, e.g. a GPS fix that fell back to an inland default, or a tap out
    // in open ocean, legitimately has none. Previously this fell through to
    // a chart built from default fallback bounds (0-1.5m) with no data and
    // no explanation, which just looked broken/stuck loading -- an honest
    // empty state instead of a fake-looking chart.
    if (tides.isEmpty) {
      return const _NoTideDataCard();
    }
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final heights = tides.map((t) => t.heightM).toList();
    final maxH =
        heights.isEmpty ? 1.5 : heights.reduce((a, b) => a > b ? a : b);
    final minH =
        heights.isEmpty ? 0.0 : heights.reduce((a, b) => a < b ? a : b);
    final range = maxH - minH;
    final highs = tides.where((t) => t.isHighTide).toList();
    final nextHigh =
        highs.isEmpty ? '--:--' : DateFormat('HH:mm').format(highs.first.time);
    final today = tides.take(4).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.tidePredictionsTitle,
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fg1)),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: 0.5,
                            getTitlesWidget: (val, _) => Text(
                                '${val.toStringAsFixed(1)}m',
                                style: AppTextStyles.overline(locale)
                                    .copyWith(color: AppColors.fg3)),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 20,
                            interval: 12,
                            getTitlesWidget: (val, _) {
                              final h = val.toInt();
                              if (h % 24 != 0 || h == 0) {
                                return const SizedBox.shrink();
                              }
                              final day = tides.isEmpty
                                  ? null
                                  : tides.first.time.add(Duration(hours: h));
                              return Text(
                                day != null ? DateFormat('d').format(day) : '',
                                style: AppTextStyles.overline(locale)
                                    .copyWith(color: AppColors.fg3),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: tides.isEmpty
                              ? []
                              : tides
                                  .map((t) => FlSpot(
                                      t.time
                                              .difference(tides.first.time)
                                              .inMinutes /
                                          60.0,
                                      t.heightM))
                                  .toList(),
                          isCurved: true,
                          color: AppColors.marineBlue,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      minY: minH - 0.1,
                      maxY: maxH + 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    l10n.todayDateLabel(
                        DateFormat('d MMMM').format(DateTime.now())),
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fg1)),
                const SizedBox(height: AppSpacing.sm),
                ...today.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text(DateFormat('HH:mm').format(t.time),
                              style: AppTextStyles.body(locale)
                                  .copyWith(color: AppColors.fg3)),
                          const SizedBox(width: AppSpacing.base),
                          Text('${t.heightM.toStringAsFixed(1)} m',
                              style: AppTextStyles.h3(locale).copyWith(
                                  color: t.isHighTide
                                      ? AppColors.deepSeaBlue
                                      : AppColors.fg3)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (t.isHighTide
                                      ? AppColors.deepSeaBlue
                                      : AppColors.fg3)
                                  .withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    t.isHighTide
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 12,
                                    color: t.isHighTide
                                        ? AppColors.deepSeaBlue
                                        : AppColors.fg3),
                                const SizedBox(width: 2),
                                Text(t.isHighTide ? l10n.highBadgeLabel : l10n.lowBadgeLabel,
                                    style: AppTextStyles.overline(locale)
                                        .copyWith(
                                            color: t.isHighTide
                                                ? AppColors.deepSeaBlue
                                                : AppColors.fg3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                  child: _StatTile(
                      label: l10n.tidalRangeAllCapsLabel,
                      value: '${range.toStringAsFixed(1)} m')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: _StatTile(
                      label: l10n.nextHighAllCapsLabel,
                      value: nextHigh,
                      valueColor: AppColors.deepSeaBlue)),
              const SizedBox(width: AppSpacing.sm),
              // No free real-time salinity source exists (matches
              // OceanCurrent.salinityPpt, which is always null server-side)
              // -- shown as unavailable rather than fabricated.
              Expanded(child: _StatTile(label: l10n.salinityAllCapsLabel, value: '')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
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

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        LoadingShimmer(
            width: double.infinity,
            height: 220,
            borderRadius: AppSpacing.radiusLg),
        SizedBox(height: AppSpacing.base),
        LoadingShimmer(
            width: double.infinity,
            height: 160,
            borderRadius: AppSpacing.radiusLg),
      ],
    );
  }
}

/// Shown instead of a fake-looking blank chart when tides are genuinely
/// unavailable for the current point (too far from a coastal reference
/// station) -- no Retry button, since retrying the same out-of-range point
/// won't change the outcome. See _TideContent's check.
class _NoTideDataCard extends StatelessWidget {
  const _NoTideDataCard();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.waves_rounded, size: 40, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.noTideDataTitle,
              style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg1)),
          const SizedBox(height: AppSpacing.xs),
          Text(
              l10n.noTideDataDescription,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg2)),
          const SizedBox(height: AppSpacing.base),
          SeaLankaButton(label: AppLocalizations.of(context)!.retry, fullWidth: false, onPressed: onRetry),
        ],
      ),
    );
  }
}
