import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/constants/foreign_eez_boundaries.dart';
import 'package:sea_lanka/core/constants/sri_lanka_eez.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_header.dart';
import 'package:sea_lanka/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';
import 'package:sea_lanka/features/pfz/presentation/bloc/pfz_bloc.dart';
import 'package:sea_lanka/features/pfz/presentation/pages/zone_detail_bottom_sheet.dart';

const double _kHeatmapZoomThreshold = 9.0;

/// Species display colors — reuses existing app accent tokens rather than
/// inventing a new palette (yellowfin=gold/CTA accent, skipjack=marine blue,
/// bigeye=danger red, billfish=deep sea blue).
Color speciesColor(String species) => switch (species) {
      PfzSpecies.yellowfin => AppColors.coralGold,
      PfzSpecies.skipjack => AppColors.marineBlue,
      PfzSpecies.bigeye => AppColors.danger,
      PfzSpecies.billfish => AppColors.deepSeaBlue,
      _ => AppColors.teal,
    };

class PfzMapPage extends StatelessWidget {
  const PfzMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PfzBloc>()..add(PfzZonesRequested(DateTime.now())),
      child: const _PfzMapView(),
    );
  }
}

class _PfzMapView extends StatefulWidget {
  const _PfzMapView();

  @override
  State<_PfzMapView> createState() => _PfzMapViewState();
}

class _PfzMapViewState extends State<_PfzMapView> {
  final MapController _mapController = MapController();
  // Captures the live FlutterMap (real OSM tiles + EEZ outline + zone
  // markers) for the PDF export, in place of the old hand-drawn vector-only
  // map -- see _captureMapImage.
  final GlobalKey _mapCaptureKey = GlobalKey();
  DateTime _selectedDate = DateTime.now();
  double _zoom = 6.5;

  // Copernicus's live forecast horizon is ~10 days; the backend never pads
  // beyond what it actually scored, so a date past the horizon just returns
  // an empty list — handled as a normal "no picks" state, not an error.
  late final List<DateTime> _dates =
      List.generate(10, (i) => DateTime.now().add(Duration(days: i)));

  // null = all species. Client-side filter over the day's already-fetched
  // picks -- one network call per date, chips just narrow what's shown.
  String? _speciesFilter;

  bool _exporting = false;

  // Fetched once on open, independent of the PFZ bloc -- a zone's
  // suitability % says nothing about safety, so an active weather alert
  // must show alongside the "good fishing" labels rather than the
  // fisherman only seeing one or the other.
  List<Map<String, dynamic>> _activeAlerts = [];

  // Backs the on-screen watermark below -- screenshots/screen recordings
  // of this page leak the same picks a PDF export would, and neither
  // platform can reliably block a screenshot, so the deterrent is baked
  // into the rendered screen itself instead (same name used for the PDF
  // export's watermark, from the same cached-user source, fetched once).
  String? _userName;

  final StreamController<void> _heatmapReset = StreamController<void>.broadcast();

  @override
  void initState() {
    super.initState();
    _loadActiveAlerts();
    sl<AuthLocalDataSource>().getCachedUser().then((user) {
      if (mounted) setState(() => _userName = user?.name);
    });
  }

  @override
  void dispose() {
    _heatmapReset.close();
    super.dispose();
  }

  Future<void> _loadActiveAlerts() async {
    try {
      final response = await sl<Dio>().get(ApiEndpoints.safetyAlerts);
      final now = DateTime.now();
      final active = (response.data as List)
          .cast<Map<String, dynamic>>()
          .where((a) {
            final expiresAt = a['expires_at'] as String?;
            return expiresAt == null || DateTime.parse(expiresAt).isAfter(now);
          })
          .toList();
      if (mounted) setState(() => _activeAlerts = active);
    } catch (_) {
      // No banner if alerts can't be fetched -- never block the zone map.
    }
  }

  /// Fits the map to every pick's location, waits for tiles to load, and
  /// captures the live FlutterMap (real OSM basemap + EEZ outline + colored
  /// zone markers) via its RepaintBoundary -- replaces the old vector-only
  /// EEZ outline + dots drawn straight into the PDF, which had no real map
  /// context at all. Restores the original camera position afterward so
  /// export never leaves the user's on-screen view changed.
  Future<Uint8List?> _captureMapImage(List<PfzPick> zones) async {
    final originalCamera = _mapController.camera;
    try {
      if (zones.isNotEmpty) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
              zones.map((z) => LatLng(z.lat, z.lon)).toList()),
          padding: const EdgeInsets.all(30),
        ));
        // Give the re-framed viewport's OSM tiles time to load in.
        await Future.delayed(const Duration(milliseconds: 900));
      }
      final boundary = _mapCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      _mapController.move(originalCamera.center, originalCamera.zoom);
    }
  }

  Future<void> _export() async {
    final state = context.read<PfzBloc>().state;
    final zones = state is PfzZonesLoaded ? state.zones : <PfzPick>[];
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // Server-side daily export cap -- a soft deterrent against one
      // account mass-producing a month's worth of picks for bulk
      // resale/sharing (see sealanka-be's POST /pfz/export). Best-effort:
      // only blocks on an explicit 429, never fails the export over an
      // unrelated network hiccup.
      try {
        await sl<Dio>().post(ApiEndpoints.pfzExport);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.exportLimitReached),
              backgroundColor: AppColors.danger,
            ));
          }
          return;
        }
      }

      // Weather advisory for the PDF, if conditions at the fisherman's own
      // location are currently notable -- same GET /weather/summary and
      // thresholds the home page's banner uses, fetched fresh here rather
      // than importing home_page.dart's private _AdvisoryBanner class.
      Map<String, dynamic>? weather;
      try {
        final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
        final response = await sl<Dio>().get(ApiEndpoints.weatherSummary,
            queryParameters: {'lat': lat, 'lon': lon});
        weather = response.data as Map<String, dynamic>;
      } catch (_) {
        // No weather data is fine -- the PDF just omits the advisory
        // section rather than failing the whole export over it.
      }
      final mapImage = await _captureMapImage(zones);
      final logoBytes = await rootBundle.load('assets/images/logo/logo-mark.png');
      // Traceability watermark: names the exporting account on every page
      // (see _buildPfzPdf's buildBackground) -- a reshared PDF can be
      // traced back to a specific subscriber, since nothing can stop
      // resharing a file already on someone's phone.
      final exporter = await sl<AuthLocalDataSource>().getCachedUser();
      final bytes = await _buildPfzPdf(
        zones: zones,
        selectedDate: _selectedDate,
        speciesFilter: _speciesFilter,
        weather: weather,
        logo: logoBytes.buffer.asUint8List(),
        mapImage: mapImage,
        exporterName: exporter?.name,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'sealanka_fishing_zones.pdf');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PfzBloc, PfzState>(
      // The map used to always open centered on a fixed Sri Lanka point at
      // a fixed zoom -- fine when every pick is near the coast, but a
      // long-range/international-waters pick (see PfzPick.longRange) could
      // sit well outside that fixed view, so a fisherman would never see
      // it without manually panning/zooming out. Refit the camera to
      // whatever the day's real picks actually span, every time they load.
      listenWhen: (prev, curr) => curr is PfzZonesLoaded,
      listener: (context, state) {
        if (state is! PfzZonesLoaded || state.zones.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(
                state.zones.map((z) => LatLng(z.lat, z.lon)).toList()),
            padding: const EdgeInsets.all(40),
            maxZoom: 8,
          ));
        });
      },
      child: Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          SeaLankaHeader(
            title: AppLocalizations.of(context)!.fishingZonesSection,
            leading: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              // /pfz is a ShellRoute leaf reached via context.go() (bottom
              // nav replaces location, doesn't push) — maybePop() has
              // nothing to pop back to, so go home explicitly instead.
              onTap: () => context.go(AppRoutes.home),
            ),
            actions: [
              GestureDetector(
                onTap: _exporting ? null : _export,
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
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
              const DataStatusBadge(status: DataStatus.live),
            ],
          ),
          if (_activeAlerts.isNotEmpty) _ActiveAlertBanner(count: _activeAlerts.length),
          _DateScroller(
            dates: _dates,
            selected: _selectedDate,
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
              context.read<PfzBloc>().add(PfzZonesRequested(date));
              _heatmapReset.add(null);
            },
          ),
          _SpeciesChipRow(
            selected: _speciesFilter,
            onSelected: (species) {
              setState(() => _speciesFilter = species);
              _heatmapReset.add(null);
            },
          ),
          Expanded(
            flex: 6,
            child: _buildMap(context),
          ),
          SizedBox(
            height: 150,
            child: BlocBuilder<PfzBloc, PfzState>(
              builder: (context, state) {
                final zones =
                    state is PfzZonesLoaded ? state.zones : <PfzPick>[];
                return _SpeciesCardsStrip(
                  allPicks: zones,
                  selectedSpecies: _speciesFilter,
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    return BlocBuilder<PfzBloc, PfzState>(
      builder: (context, state) {
        final allZones = state is PfzZonesLoaded ? state.zones : <PfzPick>[];
        final zones = _speciesFilter == null
            ? allZones
            : allZones.where((z) => z.species == _speciesFilter).toList();
        return Stack(
          children: [
            RepaintBoundary(
              key: _mapCaptureKey,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(8.5, 80.7),
                  initialZoom: 6.5,
                  minZoom: 4,
                  maxZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    if ((camera.zoom >= _kHeatmapZoomThreshold) !=
                        (_zoom >= _kHeatmapZoomThreshold)) {
                      setState(() => _zoom = camera.zoom);
                    } else {
                      _zoom = camera.zoom;
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pelajiclabs.sea_lanka',
                  ),
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: kSriLankaEezBoundary,
                        color: AppColors.marineBlue.withOpacity(0.06),
                        borderColor: AppColors.marineBlue.withOpacity(0.6),
                        borderStrokeWidth: 1.5,
                      ),
                      // Neighboring countries' EEZs -- crossing into one is
                      // a real legal/safety risk, so these are styled
                      // distinctly (danger-toned, no fill) from Sri Lanka's
                      // own boundary above. See _MapLegend.
                      for (final rings in kForeignEezBoundaries.values)
                        for (final ring in rings)
                          Polygon(
                            points: ring,
                            color: Colors.transparent,
                            borderColor: AppColors.danger.withOpacity(0.55),
                            borderStrokeWidth: 1.2,
                          ),
                    ],
                  ),
                  if (_zoom < _kHeatmapZoomThreshold && zones.isNotEmpty)
                    HeatMapLayer(
                      heatMapDataSource: InMemoryHeatMapDataSource(
                        data: zones
                            .map((z) => WeightedLatLng(
                                LatLng(z.lat, z.lon), z.calibratedProbability))
                            .toList(),
                      ),
                      heatMapOptions: HeatMapOptions(
                        gradient: {
                          0.3: Colors.red,
                          0.6: Colors.orange,
                          1.0: Colors.amber,
                        },
                        radius: 42,
                        minOpacity: 0.55,
                        blurFactor: 0.7,
                        layerOpacity: 0.85,
                      ),
                      reset: _heatmapReset.stream,
                    )
                  else
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 75,
                        size: const Size(44, 44),
                        zoomToBoundsOnClick: true,
                        spiderfyCluster: true,
                        markers: zones.map((zone) {
                          return Marker(
                            point: LatLng(zone.lat, zone.lon),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () => _showZoneDetail(context, zone),
                              child: _ZoneMarker(
                                color: _zoneColor(zone),
                                label:
                                    '${(zone.calibratedProbability * 100).toInt()}%',
                                longRange: zone.longRange,
                              ),
                            ),
                          );
                        }).toList(),
                        builder: (context, markers) {
                          // Cluster bubble: show count, colored by the
                          // highest-probability zone inside the cluster so a
                          // hot zone hiding in a cluster is still visible.
                          final clusterZones = markers.map((m) {
                            final point = m.point;
                            return zones.firstWhere(
                              (z) =>
                                  z.lat == point.latitude &&
                                  z.lon == point.longitude,
                            );
                          }).toList();
                          final maxZone = clusterZones.reduce((a, b) =>
                              a.calibratedProbability >= b.calibratedProbability
                                  ? a
                                  : b);
                          return _ZoneMarker(
                            color: _zoneColor(maxZone),
                            label: '${markers.length}',
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: _MapLegend(),
            ),
            Positioned(
              bottom: AppSpacing.base,
              right: AppSpacing.md,
              child: _ZoomControls(controller: _mapController),
            ),
            if (state is PfzLoading)
              const Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: LoadingShimmer(width: 64, height: 24, borderRadius: 12),
              ),
            if (state is PfzZonesLoaded && zones.isEmpty)
              const Center(child: _NoPicksToday()),
            if (state is PfzError)
              Center(child: _MapError(message: state.message)),
            if (_userName != null)
              Positioned.fill(
                child: IgnorePointer(child: _MapWatermark(name: _userName!)),
              ),
          ],
        );
      },
    );
  }

  void _showZoneDetail(BuildContext context, PfzPick zone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ZoneDetailBottomSheet(pick: zone),
    );
  }

  Color _zoneColor(PfzPick zone) {
    if (zone.isHighProbability) return AppColors.probHigh2;
    if (zone.isMidProbability) return AppColors.probMid2;
    return AppColors.probLow1;
  }
}

/// Faint, unavoidable repeated name/date stamp across the map -- screenshots
/// and screen recordings can't be reliably blocked on either platform (only
/// Android's FLAG_SECURE comes close, and iOS has no equivalent), so the
/// deterrent is baked into what's actually rendered instead: any capture of
/// this screen carries the same traceability mark as the PDF export.
class _MapWatermark extends StatelessWidget {
  final String name;
  const _MapWatermark({required this.name});

  @override
  Widget build(BuildContext context) {
    final label =
        '$name · ${DateFormat('MMM d, yyyy').format(DateTime.now())}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = (constraints.maxHeight / 130).ceil().clamp(2, 8);
        return Stack(
          children: [
            for (int i = 0; i < rows; i++)
              Positioned(
                left: 12,
                top: 40.0 + i * 130,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Opacity(
                    opacity: 0.10,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Colored circular pin used both for individual zones (shows `%`) and
/// cluster bubbles (shows zone count) — same visual language either way.
/// A dashed white outline flags a long-range pick (beyond that species'
/// typical fished distance) — only meaningful per-pick, so cluster bubbles
/// never show it.
class _ZoneMarker extends StatelessWidget {
  final Color color;
  final String label;
  final bool longRange;
  const _ZoneMarker(
      {required this.color, required this.label, this.longRange = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: longRange ? AppColors.warning : Colors.white,
          width: longRange ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.45), blurRadius: 10),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.caption(Localizations.localeOf(context))
              .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            color: AppColors.fgOnDark, size: 18),
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  final String message;
  const _MapError({required this.message});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SeaLankaCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.sm),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg2)),
        ],
      ),
    );
  }
}

/// Empty picks for a day/species is a valid model outcome (nothing cleared
/// the safety gates), never an error state — must read as such.
class _NoPicksToday extends StatelessWidget {
  const _NoPicksToday();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SeaLankaCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.waves_rounded, size: 40, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.of(context)!.noResponsiblePicks,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg1)),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.tryAnotherDayOrSpecies,
              style:
                  AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Active weather alert banner — a zone's suitability % says nothing about
// safety, so this sits directly above the zone list/map rather than only
// in the Alerts tab, where a fisherman might never look before heading out.
// ────────────────────────────────────────────────────────────────
class _ActiveAlertBanner extends StatelessWidget {
  final int count;
  const _ActiveAlertBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return GestureDetector(
      onTap: () => context.push(AppRoutes.alerts),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.danger, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                count == 1
                    ? AppLocalizations.of(context)!
                        .activeWeatherAdvisorySingular
                    : AppLocalizations.of(context)!
                        .activeWeatherAdvisoryPlural(count),
                style: AppTextStyles.caption(locale).copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 10-Day Date Scroller
// ────────────────────────────────────────────────────────────────
class _DateScroller extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onDateSelected;

  const _DateScroller({
    required this.dates,
    required this.selected,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) => _DateChip(
          date: dates[i],
          isSelected: DateUtils.isSameDay(dates[i], selected),
          isToday: DateUtils.isSameDay(dates[i], DateTime.now()),
          onTap: () => onDateSelected(dates[i]),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;
  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final fg = isSelected ? AppColors.midnightNavy : AppColors.fg1;
    final muted = isSelected ? AppColors.midnightNavy : AppColors.fg3;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.ctaGradient : null,
          color: isSelected ? null : AppColors.cardLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.borderLight),
          boxShadow: isSelected ? AppShadows.card : null,
        ),
        transform:
            isSelected ? (Matrix4.identity()..scale(1.06)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('E').format(date).substring(0, 3).toUpperCase(),
              style: AppTextStyles.overline(locale).copyWith(color: muted),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('d').format(date),
              style: AppTextStyles.h3(locale).copyWith(color: fg),
            ),
            const SizedBox(height: 2),
            if (isToday && !isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.marineBlue,
                  shape: BoxShape.circle,
                ),
              )
            else
              Text(
                DateFormat('MMM').format(date).toUpperCase(),
                style: AppTextStyles.overline(locale).copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Species Filter Chips — the 4 real PFZ v5 species. null = all.
// ────────────────────────────────────────────────────────────────
class _SpeciesChipRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _SpeciesChipRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...PfzSpecies.all];
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.cardLight,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final species = options[i];
          final isSelected = species == selected;
          final locale = Localizations.localeOf(context);
          final label = species == null
              ? AppLocalizations.of(context)!.allSpecies
              : PfzSpecies.label(species);
          final dotColor = species == null ? null : speciesColor(species);
          return GestureDetector(
            onTap: () => onSelected(species),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.deepSeaBlue : AppColors.cardLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: isSelected
                      ? AppColors.deepSeaBlue
                      : AppColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.caption(locale).copyWith(
                      color: isSelected ? AppColors.fgOnDark : AppColors.fg2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Species Cards Strip — real top pick per species for the selected day.
// ────────────────────────────────────────────────────────────────
class _SpeciesCardsStrip extends StatelessWidget {
  final List<PfzPick> allPicks;
  final String? selectedSpecies;
  const _SpeciesCardsStrip(
      {required this.allPicks, required this.selectedSpecies});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final species =
        selectedSpecies == null ? PfzSpecies.all : [selectedSpecies!];

    // Best (lowest rank) pick per species, if any passed the gates today.
    final topPicks = <String, PfzPick>{};
    for (final p in allPicks) {
      final current = topPicks[p.species];
      if (current == null || p.rank < current.rank) topPicks[p.species] = p;
    }
    final items = species.where((s) => topPicks.containsKey(s)).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Text(
              AppLocalizations.of(context)!.topPickPerSpecies,
              style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg1),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: items.isEmpty
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    child: Text(
                      AppLocalizations.of(context)!.noPicksPassedGates,
                      style: AppTextStyles.caption(locale)
                          .copyWith(color: AppColors.fg3),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (_, i) =>
                        _SpeciesCard(pick: topPicks[items[i]]!),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final PfzPick pick;
  const _SpeciesCard({required this.pick});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final accent = speciesColor(pick.species);
    final percent = (pick.calibratedProbability * 100).round();
    return SizedBox(
      width: 260,
      child: SeaLankaCard(
        accentColor: accent,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(Icons.set_meal_rounded, color: accent, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          PfzSpecies.label(pick.species),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(locale)
                              .copyWith(color: AppColors.fg1),
                        ),
                      ),
                      Text('$percent%',
                          style:
                              AppTextStyles.h3(locale).copyWith(color: accent)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 4,
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                      AppLocalizations.of(context)!.distFromCoast(
                          pick.distCoastKm.toStringAsFixed(0)),
                      style: AppTextStyles.caption(locale)
                          .copyWith(color: AppColors.fg3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Map Helpers
// ────────────────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withOpacity(0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.skyBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(
              color: AppColors.probHigh2,
              label: AppLocalizations.of(context)!.legendHigh),
          const SizedBox(height: AppSpacing.xs),
          _LegendItem(
              color: AppColors.probMid2,
              label: AppLocalizations.of(context)!.legendMedium),
          const SizedBox(height: AppSpacing.xs),
          _LegendItem(
              color: AppColors.probLow1,
              label: AppLocalizations.of(context)!.legendLow),
          const SizedBox(height: AppSpacing.xs),
          _LegendLine(
              color: AppColors.danger,
              label: AppLocalizations.of(context)!.legendForeignWaters),
        ],
      ),
    );
  }
}

/// Line-swatch legend row -- distinct from _LegendItem's dot, since the
/// foreign-EEZ boundary is drawn as an outline, not a filled marker.
class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color.withOpacity(0.55)),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTextStyles.caption(locale)
                .copyWith(color: AppColors.fgOnDark)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTextStyles.caption(locale)
                .copyWith(color: AppColors.fgOnDark)),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final MapController controller;
  const _ZoomControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withOpacity(0.75),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.skyBlue.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ZoomButton(
            icon: Icons.add_rounded,
            onTap: () => controller.move(
                controller.camera.center, controller.camera.zoom + 1),
          ),
          Container(
            width: 36,
            height: 1,
            color: AppColors.skyBlue.withOpacity(0.3),
          ),
          _ZoomButton(
            icon: Icons.remove_rounded,
            onTap: () => controller.move(
                controller.camera.center, controller.camera.zoom - 1),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: AppColors.fgOnDark),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PDF export -- map is a real screenshot of the live FlutterMap (real OSM
// basemap + EEZ outline + colored zone markers), captured via
// RepaintBoundary in _captureMapImage after fitting the camera to all picks
// (falls back to a bare vector EEZ outline + dots only if that capture
// fails), full details table, weather advisory if conditions are currently
// notable, and a watermark + copyright footer on every page.
// ─────────────────────────────────────────
Future<Uint8List> _buildPfzPdf({
  required List<PfzPick> zones,
  required DateTime selectedDate,
  required String? speciesFilter,
  required Map<String, dynamic>? weather,
  required Uint8List logo,
  Uint8List? mapImage,
  String? exporterName,
}) async {
  final picks = speciesFilter == null
      ? zones
      : zones.where((z) => z.species == speciesFilter).toList();
  final logoImage = pw.MemoryImage(logo);
  final capturedMap = mapImage == null ? null : pw.MemoryImage(mapImage);
  final doc = pw.Document();

  // Equirectangular projection into a fixed map box -- fine at this scale
  // (Sri Lanka's EEZ spans only a few degrees), same simplification the
  // app's own mini-map widgets already use.
  const mapW = 240.0, mapH = 260.0;
  double px(double lon) => (lon - 77.0) / (85.3 - 77.0) * mapW;
  double py(double lat) => mapH - (lat - 2.3) / (11.6 - 2.3) * mapH;

  final tierColor = <String, PdfColor>{
    'high': PdfColors.orange700,
    'mid': PdfColors.deepOrange400,
    'low': PdfColors.red400,
  };
  String tierOf(PfzPick p) =>
      p.isHighProbability ? 'high' : (p.isMidProbability ? 'mid' : 'low');

  final windKn = (weather?['wind_speed_knots'] as num?)?.toDouble();
  final waveM = (weather?['wave_height_m'] as num?)?.toDouble();
  final rainPct = (weather?['rain_chance_percent'] as num?)?.toDouble();
  final advisoryNotable =
      (windKn ?? 0) >= 17 || (waveM ?? 0) >= 2.0 || (rainPct ?? 0) >= 60;
  final advisoryParts = <String>[
    if ((windKn ?? 0) >= 17) 'wind ${windKn!.toStringAsFixed(0)} kn',
    if ((waveM ?? 0) >= 2.0) 'waves ${waveM!.toStringAsFixed(1)} m',
    if ((rainPct ?? 0) >= 60) 'rain chance ${rainPct!.toStringAsFixed(0)}%',
  ];

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        // Two layers: the original faint brand logo, plus (when the
        // exporting user is known) a faint diagonal traceability stamp
        // naming the account + export time -- so a reshared/forwarded copy
        // can be traced back to a specific subscriber. Repeated a few times
        // down the page so cropping/screenshotting a section still keeps
        // at least one stamp.
        buildBackground: (_) => pw.SizedBox(
          width: PdfPageFormat.a4.width,
          height: PdfPageFormat.a4.height,
          child: pw.Stack(
            children: [
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.06,
                  child: pw.Image(logoImage, width: 320),
                ),
              ),
              if (exporterName != null)
                for (final top in [90.0, 380.0, 670.0])
                  pw.Positioned(
                    left: 40,
                    top: top,
                    child: pw.Transform.rotate(
                      angle: -0.4,
                      child: pw.Opacity(
                        opacity: 0.12,
                        child: pw.Text(
                          'Exported for $exporterName · ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
      footer: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Copyright ${DateTime.now().year} Pelajic Labs (Pvt) Ltd -- Sea Lanka  |  Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(children: [
              pw.Image(logoImage, width: 28, height: 28),
              pw.SizedBox(width: 8),
              pw.Text('Sea Lanka -- Fishing Zones Report',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Text(DateFormat('MMM d, yyyy').format(selectedDate),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ),
      build: (_) => [
        if (advisoryNotable) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('WEATHER ADVISORY',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800)),
                pw.SizedBox(height: 3),
                pw.Text(
                  '${advisoryParts.join(', ')} right now. Check conditions before heading out.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
        ],
        pw.Text('Zone overview',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Container(
            width: mapW,
            height: mapH,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            // Real OSM basemap + EEZ outline + colored zone markers,
            // captured live from the on-screen map (see _captureMapImage)
            // -- falls back to the old vector-only EEZ outline + dots only
            // if that capture couldn't be taken (e.g. render error).
            child: capturedMap != null
                ? pw.Image(capturedMap, fit: pw.BoxFit.cover)
                : pw.CustomPaint(
                    size: const PdfPoint(mapW, mapH),
                    painter: (canvas, size) {
                      canvas.setStrokeColor(PdfColors.blue300);
                      canvas.setLineWidth(1);
                      const b = kSriLankaEezBoundary;
                      canvas.moveTo(px(b.first.longitude), py(b.first.latitude));
                      for (final p in b.skip(1)) {
                        canvas.lineTo(px(p.longitude), py(p.latitude));
                      }
                      canvas.closePath();
                      canvas.strokePath();
                      for (final z in picks) {
                        canvas.setColor(tierColor[tierOf(z)]!);
                        canvas.drawEllipse(px(z.lon), py(z.lat), 2.5, 2.5);
                        canvas.fillPath();
                      }
                    },
                  ),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _pdfLegendDot(PdfColors.orange700, 'High >=70%'),
            pw.SizedBox(width: 14),
            _pdfLegendDot(PdfColors.deepOrange400, 'Medium 40-69%'),
            pw.SizedBox(width: 14),
            _pdfLegendDot(PdfColors.red400, 'Low <40%'),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text('Ranked picks (${picks.length})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.6),
            1: pw.FlexColumnWidth(0.7),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1.1),
            4: pw.FlexColumnWidth(1.6),
            5: pw.FlexColumnWidth(1),
            6: pw.FlexColumnWidth(0.9),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _pdfCell('Species', bold: true),
                _pdfCell('Rank', bold: true),
                _pdfCell('Suitability', bold: true),
                _pdfCell('From coast', bold: true),
                _pdfCell('Position', bold: true),
                _pdfCell('Past catches', bold: true),
                _pdfCell('Long-range', bold: true),
              ],
            ),
            for (final z in picks)
              pw.TableRow(children: [
                _pdfCell(PfzSpecies.label(z.species)),
                _pdfCell('#${z.rank}'),
                _pdfCell('${(z.calibratedProbability * 100).round()}%'),
                _pdfCell('${z.distCoastKm.toStringAsFixed(0)} km'),
                _pdfCell('${z.lat.toStringAsFixed(3)}, ${z.lon.toStringAsFixed(3)}'),
                _pdfCell('${z.historyCount}'),
                _pdfCell(z.longRange ? 'Yes' : ''),
              ]),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Suitability is how favourable conditions look, not a guarantee of a catch. '
          'PFZ model ${picks.isNotEmpty ? picks.first.modelVersion : "n/a"}, refreshed daily.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfLegendDot(PdfColor color, String label) => pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 6,
          height: 6,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    );

pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
