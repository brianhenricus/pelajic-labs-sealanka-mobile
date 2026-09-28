import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/constants/sri_lanka_eez.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/data_status_badge.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';

// Roughly the middle of Sri Lanka's fishing grounds -- this is a
// country-wide activity map (like the PFZ map), not a "near me" view, so it
// always centers here rather than on the device's own GPS position.
const LatLng _kSriLankaCentroid = LatLng(7.8, 80.8);

/// One individual named vessel plotted on the map (see GET
/// /marine/vessels/all) -- lat/lon is the vessel's 0.1° grid cell, not an
/// exact AIS position (GFW's public API has none), so several vessels in
/// the same cell share identical coordinates; the map applies a small
/// deterministic jitter (seeded by vesselId) purely so overlapping markers
/// stay visually distinguishable -- never presented as a real position.
class VesselMapEntry {
  final String vesselId;
  final double lat;
  final double lon;
  final String? shipname;
  final String? mmsi;
  final String? flag;
  final String? geartype;
  final double fishingHours;

  VesselMapEntry({
    required this.vesselId,
    required this.lat,
    required this.lon,
    required this.shipname,
    required this.mmsi,
    required this.flag,
    required this.geartype,
    required this.fishingHours,
  });

  factory VesselMapEntry.fromJson(Map<String, dynamic> json) => VesselMapEntry(
        vesselId: json['vessel_id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        shipname: json['shipname'] as String?,
        mmsi: json['mmsi'] as String?,
        flag: json['flag'] as String?,
        geartype: json['geartype'] as String?,
        fishingHours: (json['fishing_hours'] as num).toDouble(),
      );

  // Stable per-vessel offset within roughly a third of the 0.1° cell --
  // deterministic (same vessel always lands in the same spot on refresh),
  // derived from vesselId's hash rather than random, so markers don't jump
  // around between rebuilds.
  LatLng get jitteredPoint {
    final h = vesselId.hashCode;
    final dLat = ((h & 0xFFFF) / 0xFFFF - 0.5) * 0.03;
    final dLon = (((h >> 16) & 0xFFFF) / 0xFFFF - 0.5) * 0.03;
    return LatLng(lat + dLat, lon + dLon);
  }

  // Decorative only -- GFW's gridded data has no real heading, so this
  // isn't presented as one anywhere (no compass/heading label in the detail
  // sheet). Purely so a map full of arrows doesn't look like a repeated
  // stamped pattern all facing the same way. Deterministic (same vessel ID
  // always gets the same angle) so it doesn't flicker between rebuilds.
  double get decorativeRotationRadians {
    final h = (vesselId.hashCode >> 8) & 0xFFFF;
    return (h / 0xFFFF) * 2 * 3.14159265;
  }
}

Future<(List<VesselMapEntry>, DateTime?)> _fetchAllVessels(
    Dio dio, double lat, double lon, double radiusKm) async {
  try {
    final response = await dio.get(ApiEndpoints.vesselsAll,
        queryParameters: {'lat': lat, 'lon': lon, 'radius_km': radiusKm});
    final data = response.data as Map<String, dynamic>;
    final vessels = (data['vessels'] as List)
        .map((e) => VesselMapEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final asOf =
        data['as_of'] != null ? DateTime.parse(data['as_of'] as String) : null;
    return (vessels, asOf);
  } on DioException {
    return (const <VesselMapEntry>[], null);
  }
}

// Gear type codes GFW's AIS-derived classifier actually returns for this
// fleet -- human-readable labels; falls back to the raw code for anything
// not in this short list rather than guessing.
const Map<String, String> _kGearTypeLabels = {
  'DRIFTING_LONGLINES': 'Drifting longline',
  'SET_LONGLINES': 'Set longline',
  'TRAWLERS': 'Trawler',
  'PURSE_SEINES': 'Purse seine',
  'GILLNETS': 'Gillnet',
  'POTS_AND_TRAPS': 'Pots & traps',
  'SQUID_JIGGER': 'Squid jigger',
  'GEAR': 'Fishing gear (unspecified)',
};

String _gearTypeLabel(String code) => _kGearTypeLabels[code] ?? code;

// A flag ISO3 -> display name for the distant-water fleets that actually
// show up in Sri Lankan waters' GFW data. Falls back to the raw code for
// anything not in this short list rather than guessing.
const Map<String, String> _kFlagNames = {
  'LKA': 'Sri Lanka',
  'IND': 'India',
  'CHN': 'China',
  'TWN': 'Taiwan',
  'JPN': 'Japan',
  'KOR': 'South Korea',
  'IDN': 'Indonesia',
  'MDV': 'Maldives',
  'THA': 'Thailand',
  'MYS': 'Malaysia',
  'SGP': 'Singapore',
  'PHL': 'Philippines',
};

String _flagLabel(String iso3) => _kFlagNames[iso3] ?? iso3;

/// Individual named-vessel positions (Global Fishing Watch AIS identity
/// data), not a live per-vessel feed -- GFW's public API has no raw
/// live-position endpoint, so each marker sits at the vessel's 0.1° grid
/// cell (jittered for visibility, see VesselMapEntry.jitteredPoint), not an
/// exact position. Map-based UI matching the app's other data maps
/// (PFZ/wind), plotting each vessel as a small arrowhead marker -- clustered
/// at low zoom (an unclustered layer of ~1200+ markers crashed the renderer
/// on-device), splitting into individual arrowheads on zoom/tap.
class MarineTrafficPage extends StatefulWidget {
  const MarineTrafficPage({super.key});

  @override
  State<MarineTrafficPage> createState() => _MarineTrafficPageState();
}

class _MarineTrafficPageState extends State<MarineTrafficPage> {
  final MapController _mapController = MapController();
  bool _loading = true;
  String? _error;
  List<VesselMapEntry> _vessels = const [];
  DateTime? _asOf;

  @override
  void initState() {
    super.initState();
    _requestData();
  }

  Future<void> _requestData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (vessels, asOf) = await _fetchAllVessels(
          sl<Dio>(), _kSriLankaCentroid.latitude, _kSriLankaCentroid.longitude, 700.0);
      if (!mounted) return;
      setState(() {
        _vessels = vessels;
        _asOf = asOf;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.vesselDataUnavailable;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070F1E),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onRetry: _requestData),
            Expanded(
              child: Stack(
                children: [
                  _buildMap(context),
                  if (_loading)
                    const Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: LoadingShimmer(width: 90, height: 24, borderRadius: 12),
                    ),
                  if (!_loading && _error == null)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: _SummaryPill(asOf: _asOf),
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
                  if (_error != null)
                    _ErrorView(message: _error!, onRetry: _requestData),
                  if (!_loading && _error == null && _vessels.isEmpty)
                    const Center(child: _NoActivity()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _kSriLankaCentroid,
        initialZoom: 6.5,
        minZoom: 4,
        maxZoom: 14,
        interactionOptions:
            InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pelajiclabs.sea_lanka',
        ),
        // Dark overlay, same purpose as the wind map's: keeps bright
        // markers/legend readable against OSM's light basemap.
        Container(color: Colors.black.withOpacity(0.55)),
        PolygonLayer(
          polygons: [
            Polygon(
              points: kSriLankaEezBoundary,
              color: AppColors.marineBlue.withOpacity(0.06),
              borderColor: AppColors.marineBlue.withOpacity(0.6),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        // Clustered -- an unclustered layer of ~1200+ vessel markers
        // crashed the renderer on-device (too many simultaneous widgets for
        // the GPU raster thread), so nearby vessels group into a numbered
        // bubble at low zoom and split into individual arrowhead icons on
        // zoom/tap, same pattern as the PFZ map.
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(36, 36),
            zoomToBoundsOnClick: true,
            spiderfyCluster: true,
            markers: _vessels.map((v) {
              return Marker(
                point: v.jitteredPoint,
                width: 22,
                height: 22,
                child: GestureDetector(
                  onTap: () => _showVesselDetail(context, v),
                  child: _VesselArrowMarker(
                      color: _hoursTierColor(v.fishingHours),
                      rotation: v.decorativeRotationRadians),
                ),
              );
            }).toList(),
            builder: (context, markers) {
              final clusterVessels = markers.map((m) {
                final point = m.point;
                return _vessels.firstWhere((v) =>
                    v.jitteredPoint.latitude == point.latitude &&
                    v.jitteredPoint.longitude == point.longitude);
              }).toList();
              final maxHours =
                  clusterVessels.map((v) => v.fishingHours).reduce((a, b) => a > b ? a : b);
              return _VesselClusterBubble(
                  color: _hoursTierColor(maxHours), count: markers.length);
            },
          ),
        ),
      ],
    );
  }

  // Activity tiers by this vessel's own fishing hours on the day -- same
  // green/amber/red language as the rest of the app's severity coding
  // (AppColors.success/warning/danger).
  Color _hoursTierColor(double hours) {
    if (hours >= 8) return AppColors.danger;
    if (hours >= 2) return AppColors.warning;
    return AppColors.success;
  }

  void _showVesselDetail(BuildContext context, VesselMapEntry vessel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VesselDetailSheet(vessel: vessel),
    );
  }
}

/// Small arrowhead marker -- one per vessel, colored by that vessel's
/// fishing-hours tier. The rotation is decorative only (see
/// VesselMapEntry.decorativeRotationRadians) -- GFW's gridded data has no
/// real heading, never presented as one.
class _VesselArrowMarker extends StatelessWidget {
  final Color color;
  final double rotation;
  const _VesselArrowMarker({required this.color, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Icon(Icons.navigation_rounded, color: color, size: 20,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)]),
    );
  }
}

/// Cluster bubble for a group of nearby vessels -- colored by the highest
/// fishing-hours tier inside the cluster, so a busy vessel hiding in a
/// cluster is still visible, same convention as the PFZ map's cluster bubbles.
class _VesselClusterBubble extends StatelessWidget {
  final Color color;
  final int count;
  const _VesselClusterBubble({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          '$count',
          style: AppTextStyles.caption(Localizations.localeOf(context))
              .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onRetry;
  const _TopBar({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.skyBlue.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          GestureDetector(
            // Standalone bottom-nav tab (ShellRoute leaf, replaces location
            // rather than pushing) -- go home explicitly, same fix as the
            // PFZ map's back button (nothing to pop back to here either).
            onTap: () => context.go(AppRoutes.home),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(AppLocalizations.of(context)!.marineTrafficTitle,
                style: AppTextStyles.h3(locale).copyWith(color: AppColors.fgOnDark)),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces the mockup's "Live" badge -- this is a daily-cached grid (GFW
/// has a genuine ~72h processing lag), never truly live, so it reads as
/// "CACHED · <n>D AGO" via the same DataStatusBadge used elsewhere in the
/// app rather than a dishonest live pulse.
class _SummaryPill extends StatelessWidget {
  final DateTime? asOf;
  const _SummaryPill({required this.asOf});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysAgo = asOf == null
        ? null
        : DateTime.now().toUtc().difference(asOf!).inDays;
    final detail = daysAgo == null
        ? null
        : (daysAgo <= 0 ? l10n.today : l10n.daysAgoLabel('$daysAgo'));
    return DataStatusBadge(status: DataStatus.cached, detail: detail);
  }
}

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
          _LegendItem(color: AppColors.danger, label: AppLocalizations.of(context)!.vesselTier8hPlus),
          const SizedBox(height: AppSpacing.xs),
          _LegendItem(color: AppColors.warning, label: AppLocalizations.of(context)!.vesselTier2to8h),
          const SizedBox(height: AppSpacing.xs),
          _LegendItem(color: AppColors.success, label: AppLocalizations.of(context)!.vesselTierUnder2h),
        ],
      ),
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
            style:
                AppTextStyles.caption(locale).copyWith(color: AppColors.fgOnDark)),
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
            onTap: () =>
                controller.move(controller.camera.center, controller.camera.zoom + 1),
          ),
          Container(width: 36, height: 1, color: AppColors.skyBlue.withOpacity(0.3)),
          _ZoomButton(
            icon: Icons.remove_rounded,
            onTap: () =>
                controller.move(controller.camera.center, controller.camera.zoom - 1),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white38),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(locale).copyWith(color: Colors.white60)),
            const SizedBox(height: AppSpacing.base),
            OutlinedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.retry)),
          ],
        ),
      ),
    );
  }
}

class _NoActivity extends StatelessWidget {
  const _NoActivity();

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SeaLankaCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.set_meal_rounded, size: 40, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.of(context)!.noFishingActivityMessage,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg1)),
        ],
      ),
    );
  }
}

/// Single-vessel detail sheet -- the mockup wanted speed/heading/"Track
/// vessel", but GFW's gridded data has neither (no live tracking). Shows
/// what's real: this vessel's own name/flag/gear-type/MMSI and today's
/// fishing hours, straight from the map fetch (no extra network call --
/// the data's already in hand from GET /marine/vessels/all).
class _VesselDetailSheet extends StatelessWidget {
  final VesselMapEntry vessel;
  const _VesselDetailSheet({required this.vessel});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final name = vessel.shipname?.trim();

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
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (name == null || name.isEmpty) ? l10n.unnamedVesselLabel : name,
                        style: AppTextStyles.h2(locale).copyWith(color: AppColors.fg1),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.marineBlue.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                          vessel.flag != null ? _flagLabel(vessel.flag!) : l10n.unknownFlagLabel,
                          style: AppTextStyles.overline(locale)
                              .copyWith(color: AppColors.marineBlue)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                Row(
                  children: [
                    _StatTile(
                        icon: Icons.category_rounded,
                        value: vessel.geartype != null
                            ? _gearTypeLabel(vessel.geartype!)
                            : '',
                        label: l10n.gearTypeLabel),
                    const SizedBox(width: AppSpacing.sm),
                    _StatTile(
                        icon: Icons.schedule_rounded,
                        value: '${vessel.fishingHours.toStringAsFixed(1)}h',
                        label: l10n.fishingTodayLabel),
                    const SizedBox(width: AppSpacing.sm),
                    _StatTile(
                        icon: Icons.tag_rounded,
                        value: vessel.mmsi ?? '',
                        label: l10n.mmsiLabel),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                Row(
                  children: [
                    const Icon(Icons.satellite_alt_rounded, size: 14, color: AppColors.fg3),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.vesselPositionDisclaimer,
                        style:
                            AppTextStyles.caption(locale).copyWith(color: AppColors.fg3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cardLight,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg + bottomInset),
            child: OutlinedButton.icon(
              onPressed: () => _launchNavigation(vessel),
              icon: const Icon(Icons.navigation_rounded),
              label: Text(l10n.navigateHereLabel),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchNavigation(VesselMapEntry vessel) async {
  final uri = Uri.parse('geo:${vessel.lat},${vessel.lon}?q=${vessel.lat},${vessel.lon}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
