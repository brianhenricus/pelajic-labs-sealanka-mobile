import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
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
import 'package:sea_lanka/core/widgets/compass_rose.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/particle_flow_layer.dart';
import 'package:sea_lanka/core/widgets/selected_location_marker.dart';
import 'package:sea_lanka/core/widgets/sl_segmented.dart';
import 'package:sea_lanka/core/widgets/speed_tiers.dart';
import 'package:sea_lanka/features/wind/data/datasources/wind_remote_datasource.dart';
import 'package:sea_lanka/features/wind/data/repositories/wind_repository_impl.dart';
import 'package:sea_lanka/features/wind/domain/entities/wind_data.dart';
import 'package:sea_lanka/features/wind/domain/usecases/get_current_wind_usecase.dart';
import 'package:sea_lanka/features/wind/presentation/bloc/wind_bloc.dart';

// Matches sealanka-be's ingestion bbox (wind_source.py).
const double _kBboxSouth = -2,
    _kBboxNorth = 18,
    _kBboxWest = 68,
    _kBboxEast = 92;

// Total height of the top date-picker bar (see _DayPicker) -- used to push
// the compass/legend row down below it without the two overlapping.
const double _kDayPickerHeight = 64;

String compassFromDeg(double deg) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final idx = (((deg % 360) + 22.5) ~/ 45) % 8;
  return dirs[idx];
}

// Rough Beaufort scale from knots -- matches the wind-condition tiers
// already used server-side (sealanka-be's _wind_condition), just labeled
// for display the way small-craft advisories usually phrase it.
(int, String) beaufort(double knots, AppLocalizations l10n) {
  if (knots < 1) return (0, l10n.beaufortCalm);
  if (knots < 4) return (1, l10n.beaufortLightAir);
  if (knots < 7) return (2, l10n.beaufortLightBreeze);
  if (knots < 11) return (3, l10n.beaufortGentleBreeze);
  if (knots < 16) return (4, l10n.beaufortModerateBreeze);
  if (knots < 22) return (5, l10n.beaufortFreshBreeze);
  if (knots < 28) return (6, l10n.beaufortStrongBreeze);
  if (knots < 34) return (7, l10n.beaufortNearGale);
  return (8, l10n.beaufortGale);
}

class WindOutlookPoint {
  final int forecastHour;
  final DateTime validTime;
  final double speedKnots;
  final int directionDeg;
  WindOutlookPoint({
    required this.forecastHour,
    required this.validTime,
    required this.speedKnots,
    required this.directionDeg,
  });

  factory WindOutlookPoint.fromJson(Map<String, dynamic> json) =>
      WindOutlookPoint(
        forecastHour: json['forecast_hour'] as int,
        validTime: DateTime.parse(json['valid_time'] as String),
        speedKnots: (json['speed_knots'] as num).toDouble(),
        directionDeg: json['direction_deg'] as int,
      );
}

Future<List<WindOutlookPoint>> _fetchOutlook(
    Dio dio, double lat, double lon) async {
  try {
    final response = await dio.get(ApiEndpoints.windOutlook,
        queryParameters: {'lat': lat, 'lon': lon});
    return (response.data as List)
        .map((e) => WindOutlookPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException {
    return const [];
  }
}

/// One cached RainViewer radar frame (see sealanka-be's rain_radar_service)
/// -- a tile URL template, not decoded point values (RainViewer's public
/// API is a map-tile service, same shape as the OSM basemap already used
/// here, not a JSON point-query API).
class RainRadarFrame {
  final DateTime time;
  final bool isNowcast;
  final String tileUrlTemplate;
  RainRadarFrame({
    required this.time,
    required this.isNowcast,
    required this.tileUrlTemplate,
  });

  factory RainRadarFrame.fromJson(Map<String, dynamic> json) => RainRadarFrame(
        time: DateTime.parse(json['time'] as String),
        isNowcast: json['is_nowcast'] as bool,
        tileUrlTemplate: json['tile_url_template'] as String,
      );
}

Future<List<RainRadarFrame>> _fetchRadarFrames(Dio dio) async {
  try {
    final response = await dio.get(ApiEndpoints.rainRadarFrames);
    return (response.data as List)
        .map((e) => RainRadarFrame.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException {
    return const [];
  }
}

class WindMapPage extends StatelessWidget {
  const WindMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WindBloc(
        getCurrentWind: GetCurrentWindUseCase(
          WindRepositoryImpl(
            remoteDataSource: WindRemoteDataSourceImpl(sl<Dio>()),
            networkInfo: sl<NetworkInfo>(),
          ),
        ),
      ),
      child: const _WindMapView(),
    );
  }
}

class _WindMapView extends StatefulWidget {
  const _WindMapView();

  @override
  State<_WindMapView> createState() => _WindMapViewState();
}

class _WindMapViewState extends State<_WindMapView> {
  List<List<double>> _windGrid = const [];
  List<WindOutlookPoint> _outlook = const [];
  LatLng? _selected;
  double? _headingDeg;
  StreamSubscription<CompassEvent>? _compassSub;

  // Map day picker -- forecast_hour of the currently-displayed grid (0 =
  // now/live). _dayHours lists which day-granularity lead times the server
  // actually has cached (best-effort ingestion, see wind_source.py -- a
  // far-out day can briefly be missing).
  int _selectedHour = 0;
  List<int> _dayHours = const [0];
  bool _gridLoading = false;

  // Whether the bottom conditions panel is shown -- user-closable so the
  // map is always fully visible on demand, not just partially above a
  // fixed-height panel.
  bool _sheetOpen = true;

  // Live rain radar overlay (RainViewer, see rain_radar_service.py) --
  // off by default so it doesn't visually compete with the wind particles
  // until the user asks for it.
  List<RainRadarFrame> _radarFrames = const [];
  bool _showRadar = false;

  @override
  void initState() {
    super.initState();
    _requestData();
    _loadGrid();
    _loadDayHours();
    _loadRadarFrames();
    // Null on devices/emulators with no magnetometer -- CompassRose just
    // stays north-up rather than showing a fake heading in that case.
    if (FlutterCompass.events != null) {
      _compassSub = FlutterCompass.events!.listen((event) {
        if (mounted && event.heading != null) {
          setState(() => _headingDeg = event.heading);
        }
      });
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _requestData() async {
    final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
    if (!mounted) return;
    setState(() => _selected = LatLng(lat, lon));
    context.read<WindBloc>().add(WindRequested(lat: lat, lon: lon));
    final outlook = await _fetchOutlook(sl<Dio>(), lat, lon);
    if (mounted) setState(() => _outlook = outlook);
  }

  Future<void> _loadGrid() async {
    final grid = await fetchVectorGrid(sl<Dio>(), ApiEndpoints.windGrid,
        queryParameters: {'forecast_hour': _selectedHour});
    if (mounted) setState(() => _windGrid = grid);
  }

  Future<void> _loadDayHours() async {
    try {
      final response = await sl<Dio>().get(ApiEndpoints.windForecastHours);
      final hours = (response.data as List).cast<int>();
      // Day-granularity only (0, 24, 48, ...) -- the 3-hourly hours also
      // cached for today feed the chart, not the map's day picker.
      final days = hours.where((h) => h == 0 || h % 24 == 0).toList()..sort();
      if (mounted && days.isNotEmpty) setState(() => _dayHours = days);
    } on DioException {
      // Keep the [0] default -- "Now" always works even if this call fails.
    }
  }

  Future<void> _loadRadarFrames() async {
    final frames = await _fetchRadarFrames(sl<Dio>());
    if (mounted) setState(() => _radarFrames = frames);
  }

  Future<void> _selectDay(int hour) async {
    if (hour == _selectedHour) return;
    setState(() {
      _selectedHour = hour;
      _gridLoading = true;
    });
    final grid = await fetchVectorGrid(sl<Dio>(), ApiEndpoints.windGrid,
        queryParameters: {'forecast_hour': hour});
    if (mounted) {
      setState(() {
        _windGrid = grid;
        _gridLoading = false;
      });
    }
  }

  /// The outlook entry closest to the selected map day, for the bottom
  /// sheet's reading when a future day is picked -- null (falls back to
  /// live "now" wind) when "Now" is selected or nothing's loaded yet.
  WindOutlookPoint? get _selectedDayOutlook {
    if (_selectedHour == 0 || _outlook.isEmpty) return null;
    return _outlook.reduce((a, b) => (a.forecastHour - _selectedHour).abs() <=
            (b.forecastHour - _selectedHour).abs()
        ? a
        : b);
  }

  /// Nullschool-style "tap a point to see its details" -- re-queries wind
  /// at the tapped coordinate instead of only ever showing the device's
  /// own location.
  Future<void> _onMapTap(LatLng point) async {
    setState(() => _selected = point);
    context
        .read<WindBloc>()
        .add(WindRequested(lat: point.latitude, lon: point.longitude));
    final outlook =
        await _fetchOutlook(sl<Dio>(), point.latitude, point.longitude);
    if (mounted) setState(() => _outlook = outlook);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: const LatLng(8.5, 80.7),
                        initialZoom: 5.8,
                        minZoom: 4,
                        maxZoom: 10,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                        onTap: (_, point) => _onMapTap(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.pelajiclabs.sea_lanka',
                        ),
                        // Dark overlay so the particle flow's white trails
                        // read clearly against OSM's light basemap (CARTO's
                        // dark tiles now require a paid API key).
                        Container(color: Colors.black.withOpacity(0.55)),
                        // Live rain radar (NASA GIBS IMERG satellite
                        // precipitation -- RainViewer's ground-radar mosaic
                        // has no Sri Lanka coverage) -- below the wind
                        // particles so the animated flow stays the clearest
                        // layer; toggled via the button in _TopBar.
                        if (_showRadar && _radarFrames.isNotEmpty)
                          // Wrapped in Opacity (not TileDisplay's own
                          // opacity) -- flutter_map's docs warn fading +
                          // per-tile opacity together can flicker.
                          Opacity(
                            opacity: 0.75,
                            child: TileLayer(
                              urlTemplate: _radarFrames.last.tileUrlTemplate,
                              userAgentPackageName: 'com.pelajiclabs.sea_lanka',
                              // GIBS's GoogleMapsCompatible_Level6 tile set
                              // tops out at zoom 6 -- upscale beyond that
                              // instead of requesting tiles that don't exist.
                              maxNativeZoom: 6,
                            ),
                          ),
                        if (_windGrid.isNotEmpty)
                          ParticleFlowLayer(
                            vectorPoints: _windGrid,
                            gridStep: 0.25,
                            south: _kBboxSouth,
                            north: _kBboxNorth,
                            west: _kBboxWest,
                            east: _kBboxEast,
                            speedTiers: kWindSpeedTiers,
                            speedUnitConverter: (ms) => ms * 3.6, // m/s -> km/h
                            // Same nullschool-style density bump as the
                            // currents map (see ocean_current_page.dart).
                            trailLength: 26,
                            trailIntervalMs: 45.0,
                            particleCount: 2000,
                            strokeWidth: 1.1,
                          ),
                        if (_selected != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: _selected!,
                              width: 22,
                              height: 22,
                              child: const SelectedLocationDot(),
                            ),
                          ]),
                      ],
                    ),
                  ),
                  Builder(builder: (context) {
                    // Below the header AND the date picker (both fixed
                    // Positioned bars at the top), not just AppSpacing.base
                    // from the Stack's own top -- otherwise these collide
                    // with the status bar/header row, and previously with
                    // the date picker once it moved up here too.
                    final topOffset = MediaQuery.of(context).padding.top +
                        AppSpacing.appBarHeight +
                        (_dayHours.length > 1 ? _kDayPickerHeight : 0) +
                        AppSpacing.sm;
                    return Stack(
                      children: [
                        Positioned(
                          top: topOffset,
                          left: AppSpacing.base,
                          child: BlocBuilder<WindBloc, WindState>(
                            builder: (context, state) {
                              final dir = state is WindLoaded
                                  ? state.wind.directionDeg
                                  : 0.0;
                              return CompassRose(
                                  directionDeg: dir, headingDeg: _headingDeg);
                            },
                          ),
                        ),
                        Positioned(
                          top: topOffset,
                          right: AppSpacing.base,
                          child: const SpeedLegend(
                              title: 'WIND KM/H', tiers: kWindSpeedTiers),
                        ),
                      ],
                    );
                  }),
                  // Below the header, full width, above the compass/legend
                  // row (see topOffset above) -- was overlaid lower down on
                  // the map itself, which collided with the legend and got
                  // clipped once more than a few days were cached. Real
                  // calendar dates, not "Day N", matching the Sol-Lunar
                  // page's date strip.
                  if (_dayHours.length > 1)
                    Positioned(
                      top: MediaQuery.of(context).padding.top +
                          AppSpacing.appBarHeight,
                      left: 0,
                      right: 0,
                      child: _DayPicker(
                        dayHours: _dayHours,
                        selectedHour: _selectedHour,
                        loading: _gridLoading,
                        onSelect: _selectDay,
                      ),
                    ),
                  _TopBar(
                    showRadar: _showRadar,
                    radarAvailable: _radarFrames.isNotEmpty,
                    onToggleRadar: () =>
                        setState(() => _showRadar = !_showRadar),
                  ),
                  if (_sheetOpen)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: BlocBuilder<WindBloc, WindState>(
                        builder: (context, state) {
                          if (state is WindError) {
                            return _ErrorSheet(
                                message: state.message, onRetry: _requestData);
                          }
                          if (state is WindLoaded) {
                            return _ConditionsSheet(
                                wind: state.wind,
                                outlook: _outlook,
                                dayOverride: _selectedDayOutlook,
                                selectedHour: _selectedHour,
                                onClose: () =>
                                    setState(() => _sheetOpen = false));
                          }
                          return const _LoadingSheet();
                        },
                      ),
                    )
                  else
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppSpacing.base,
                      child: Center(
                        child: _ReopenSheetButton(
                            onTap: () => setState(() => _sheetOpen = true)),
                      ),
                    ),
                ],
              ),
            ),
            // Below the map, not overlaid on top of it -- the advisory
            // still spans full width, just docked under the map instead of
            // pushing down/covering it from above.
            BlocBuilder<WindBloc, WindState>(
              builder: (context, state) {
                if (state is! WindLoaded) return const SizedBox.shrink();
                return _AdvisoryBanner(wind: state.wind, outlook: _outlook);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal day-picker for the map's particle grid -- "Now" plus whichever
/// day-granularity lead times the GFS grid ingestion actually has cached
/// (up to +10 days, see wind_source.FORECAST_HOURS). Selecting a day
/// re-fetches that day's grid so the particle flow reflects that day's
/// forecast, not just today's.
class _DayPicker extends StatelessWidget {
  final List<int> dayHours;
  final int selectedHour;
  final bool loading;
  final ValueChanged<int> onSelect;
  const _DayPicker({
    required this.dayHours,
    required this.selectedHour,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Same translucent-dark-bar treatment as _TopBar/CompassRose/SpeedLegend
    // -- this now floats directly over the map at the top, not a solid bar
    // below it, so it needs to read clearly against the map underneath.
    return Container(
      height: _kDayPickerHeight,
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withOpacity(0.72),
        border: Border(
            bottom: BorderSide(color: AppColors.skyBlue.withOpacity(0.12))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        itemCount: dayHours.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          final hour = dayHours[i];
          final date = today.add(Duration(hours: hour));
          final selected = hour == selectedHour;
          return GestureDetector(
            onTap: () => onSelect(hour),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.coralGold
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                    color: selected
                        ? AppColors.coralGold
                        : Colors.white.withOpacity(0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      hour == 0
                          ? AppLocalizations.of(context)!.nowLabel
                          : DateFormat('EEE d').format(date),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.midnightNavy
                              : Colors.white)),
                  if (loading && selected) ...[
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.midnightNavy.withOpacity(0.7)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small pill that reappears above the bottom-nav when the conditions
/// panel is closed, so it's never permanently gone -- just one tap away.
class _ReopenSheetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReopenSheetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.midnightNavy.withOpacity(0.85),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
          boxShadow: AppShadows.sheet,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(AppLocalizations.of(context)!.showConditionsLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Real-conditions + real-outlook wind warning — only shown when either the
/// current reading or the cached 24h outlook actually crosses a notable
/// threshold, using the real peak time/speed from the outlook rather than
/// a fabricated claim.
class _AdvisoryBanner extends StatelessWidget {
  final WindData wind;
  final List<WindOutlookPoint> outlook;
  const _AdvisoryBanner({required this.wind, required this.outlook});

  static const _kThresholdKnots = 17.0; // matches backend's "fresh" tier

  WindOutlookPoint? get _peakWithin24h {
    final next24h = outlook.where((p) => p.forecastHour <= 24).toList();
    if (next24h.isEmpty) return null;
    return next24h.reduce((a, b) => a.speedKnots >= b.speedKnots ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final peak = _peakWithin24h;
    final peakIsNotable = peak != null &&
        peak.speedKnots >= _kThresholdKnots &&
        peak.forecastHour > 0;
    final nowIsNotable = wind.speedKnots >= _kThresholdKnots;

    if (!peakIsNotable && !nowIsNotable) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final message = peakIsNotable
        ? l10n.windAdvisoryPeakMessage(peak.speedKnots.toStringAsFixed(0),
            TimeOfDay.fromDateTime(peak.validTime.toLocal()).format(context))
        : l10n.windAdvisoryCurrentMessage(
            wind.speedKnots.toStringAsFixed(0), wind.condition);

    return Container(
      width: double.infinity,
      color: AppColors.danger,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      // No SafeArea here -- this banner sits below the map, not at the top
      // of the screen, so a SafeArea (even bottom:false) was adding a
      // spurious top gap equal to the status bar height for no reason.
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption(locale).copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _LoadingSheet extends StatelessWidget {
  const _LoadingSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: const LoadingShimmer(
          width: double.infinity,
          height: 140,
          borderRadius: AppSpacing.radiusSheet),
    );
  }
}

class _ErrorSheet extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorSheet({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSheet)),
        boxShadow: AppShadows.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.sm),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg2)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry)),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool showRadar;
  final bool radarAvailable;
  final VoidCallback onToggleRadar;
  const _TopBar({
    required this.showRadar,
    required this.radarAvailable,
    required this.onToggleRadar,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: AppSpacing.appBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.midnightNavy.withOpacity(0.72),
            border: Border(
                bottom: BorderSide(color: AppColors.skyBlue.withOpacity(0.12))),
          ),
          child: Row(
            children: [
              GestureDetector(
                // Almanac tab (ShellRoute leaf, reached via context.go() from
                // the bottom nav, never pushed) -- nothing to pop back to,
                // same fix as pfz_map_page.dart/ocean_current_page.dart's
                // own back buttons.
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
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(AppLocalizations.of(context)!.windMapTitle,
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fgOnDark)),
              ),
              GestureDetector(
                onTap: radarAvailable ? onToggleRadar : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 6),
                  decoration: BoxDecoration(
                    color: showRadar
                        ? AppColors.coralGold
                        : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                        color: showRadar
                            ? AppColors.coralGold
                            : Colors.white.withOpacity(0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar_rounded,
                          size: 14,
                          color: radarAvailable
                              ? (showRadar
                                  ? AppColors.midnightNavy
                                  : Colors.white)
                              : Colors.white38),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.radarLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: radarAvailable
                                  ? (showRadar
                                      ? AppColors.midnightNavy
                                      : Colors.white)
                                  : Colors.white38)),
                    ],
                  ),
                ),
              ),
              const DataStatusBadge(status: DataStatus.live),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: current conditions for whichever point was last tapped (or
/// the device's own location by default) + a tabbed 24h/10-day trend chart.
/// User-closable (see onClose) so the map is always fully viewable on
/// demand, not just partially above a fixed-height panel.
class _ConditionsSheet extends StatefulWidget {
  final WindData wind;
  final List<WindOutlookPoint> outlook;
  // When set (a map day other than "Now" is selected), the headline reading
  // shows that day's forecast instead of the live current reading.
  final WindOutlookPoint? dayOverride;
  final int selectedHour;
  final VoidCallback onClose;
  const _ConditionsSheet({
    required this.wind,
    required this.outlook,
    required this.onClose,
    this.dayOverride,
    this.selectedHour = 0,
  });

  @override
  State<_ConditionsSheet> createState() => _ConditionsSheetState();
}

class _ConditionsSheetState extends State<_ConditionsSheet> {
  int _chartTab = 0; // 0 = 24h, 1 = 10-day

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final wind = widget.wind;
    final outlook = widget.outlook;
    final dayOverride = widget.dayOverride;
    final displaySpeedKnots = dayOverride?.speedKnots ?? wind.speedKnots;
    final displayDirectionDeg =
        (dayOverride?.directionDeg ?? wind.directionDeg).toDouble();
    final compass = compassFromDeg(displayDirectionDeg);
    final (scale, label) =
        beaufort(displaySpeedKnots, AppLocalizations.of(context)!);
    final speedKmh = displaySpeedKnots * 1.852;
    final has10Day = outlook.length > 24;

    return Container(
      // Capped, not sized to content -- tabbing the charts (instead of
      // always stacking both) already keeps this short in the common case,
      // but the cap + internal scroll is kept as a hard guarantee that the
      // map above it can never be fully covered regardless of content.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.42),
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSheet)),
        boxShadow: AppShadows.sheet,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      dayOverride != null
                          ? l10n.dayForecastLabel(DateFormat('EEEE, d MMM')
                              .format(dayOverride.validTime.toLocal()))
                          : l10n.currentConditionsAllCaps,
                      style: AppTextStyles.overline(locale)
                          .copyWith(color: AppColors.fg3)),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.fg3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(speedKmh.toStringAsFixed(0),
                    style: AppTextStyles.display(locale).copyWith(
                        color: AppColors.fg1, fontWeight: FontWeight.w800)),
                const SizedBox(width: AppSpacing.xs),
                Text(l10n.kmhUnitLabel,
                    style: AppTextStyles.body(locale)
                        .copyWith(color: AppColors.fg3)),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Center(
                    child: CompassNeedle(
                      directionDeg: displayDirectionDeg,
                      size: 16,
                      color: AppColors.deepSeaBlue,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(compass,
                    style: AppTextStyles.h2(locale)
                        .copyWith(color: AppColors.deepSeaBlue)),
              ],
            ),
            const SizedBox(height: 2),
            Text(l10n.beaufortScaleLabel('$scale', label),
                style: AppTextStyles.caption(locale)
                    .copyWith(color: AppColors.fg3)),
            if (dayOverride != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                    l10n.readingForTimeLabel(
                        TimeOfDay.fromDateTime(dayOverride.validTime.toLocal())
                            .format(context)),
                    style: AppTextStyles.caption(locale)
                        .copyWith(color: AppColors.fg3.withOpacity(0.8))),
              ),
            if (outlook.length > 1) ...[
              const SizedBox(height: AppSpacing.base),
              if (has10Day)
                SlSegmented(
                  segments: [l10n.hours24SegmentLabel, l10n.days10SegmentLabel],
                  selectedIndex: _chartTab,
                  onChanged: (i) => setState(() => _chartTab = i),
                )
              else
                Text(l10n.outlook24hAllCaps,
                    style: AppTextStyles.overline(locale)
                        .copyWith(color: AppColors.fg3)),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 90,
                child: (!has10Day || _chartTab == 0)
                    ? _OutlookChart(outlook: outlook)
                    : _TenDayOutlookChart(outlook: outlook),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 24h wind-speed trend line (km/h) with the real forecast peak (if any)
/// called out — matches the "25 km/h · 4 PM" style callout in the mockup,
/// built from actual outlook data rather than a fixed claim.
class _OutlookChart extends StatelessWidget {
  final List<WindOutlookPoint> outlook;
  const _OutlookChart({required this.outlook});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final next24h = outlook.where((p) => p.forecastHour <= 24).toList()
      ..sort((a, b) => a.forecastHour.compareTo(b.forecastHour));
    if (next24h.length < 2) return const SizedBox.shrink();

    final spots = next24h
        .map((p) => FlSpot(p.forecastHour.toDouble(), p.speedKnots * 1.852))
        .toList();
    final peak = next24h.reduce((a, b) => a.speedKnots >= b.speedKnots ? a : b);

    return LineChart(
      LineChartData(
        // fl_chart's default touch tooltip is unrelated to this chart's own
        // real peak-time callout (drawn via extraLinesData below) and just
        // leaves a stray floating value box behind after a tap.
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 6,
              getTitlesWidget: (val, _) => Text(
                val == 0
                    ? AppLocalizations.of(context)!.nowLabel
                    : '${val.toInt()}h',
                style: AppTextStyles.overline(locale)
                    .copyWith(color: AppColors.fg3),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.marineBlue,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.marineBlue.withOpacity(0.25),
                  AppColors.marineBlue.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(verticalLines: [
          VerticalLine(
            x: peak.forecastHour.toDouble(),
            color: AppColors.danger.withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [4, 3],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 9,
                  fontWeight: FontWeight.w700),
              labelResolver: (_) =>
                  '${peak.speedKnots * 1.852 ~/ 1} km/h · ${TimeOfDay.fromDateTime(peak.validTime.toLocal()).format(context)}',
            ),
          ),
        ]),
        minX: 0,
        maxX: 24,
      ),
    );
  }
}

/// Full real 10-day hourly trend (horizontally scrollable — 240 points is
/// too dense for a fixed-width chart to stay readable) -- day boundaries
/// labelled "Now" / "Day 2".."Day 10", separate from the 24h chart above so
/// that chart's tuned peak-callout stays untouched.
class _TenDayOutlookChart extends StatelessWidget {
  final List<WindOutlookPoint> outlook;
  const _TenDayOutlookChart({required this.outlook});

  static const _pxPerHour = 6.0;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final sorted = [...outlook]
      ..sort((a, b) => a.forecastHour.compareTo(b.forecastHour));
    final spots = sorted
        .map((p) => FlSpot(p.forecastHour.toDouble(), p.speedKnots * 1.852))
        .toList();
    final maxHour = sorted.last.forecastHour.toDouble();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width:
            math.max(MediaQuery.of(context).size.width, maxHour * _pxPerHour),
        child: LineChart(
          LineChartData(
            lineTouchData: const LineTouchData(enabled: false),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  interval: 24,
                  getTitlesWidget: (val, _) => Text(
                    val == 0
                        ? AppLocalizations.of(context)!.nowLabel
                        : 'Day ${(val / 24).round() + 1}',
                    style: AppTextStyles.overline(locale)
                        .copyWith(color: AppColors.fg3),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.marineBlue,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.marineBlue.withOpacity(0.2),
                      AppColors.marineBlue.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            minX: 0,
            maxX: maxHour,
          ),
        ),
      ),
    );
  }
}
