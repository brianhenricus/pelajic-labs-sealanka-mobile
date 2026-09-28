import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/zone_tile.dart';
import 'package:sea_lanka/features/pfz/domain/entities/pfz_pick.dart';
import 'package:sea_lanka/features/pfz/presentation/pages/pfz_map_page.dart'
    show speciesColor;
import 'package:sea_lanka/features/profile/domain/usecases/get_profile_usecase.dart';

// Used when the boat profile has no fuel/speed on file (not filled in yet,
// or account created before this feature existed) — a typical small
// artisanal fishing boat, so the estimate is still in the right ballpark.
const double _kDefaultFuelConsumptionLph = 12.0;
const double _kDefaultCruisingSpeedKnots = 8.0;
const double _kKnotsToKmh = 1.852;

/// PFZ pick detail sheet: 24dp top radius, lift shadow, drag handle, big
/// suitability hero, and a gold CTA. Public API
/// (`ZoneDetailBottomSheet(pick:)`) is unchanged from the old zone version.
class ZoneDetailBottomSheet extends StatelessWidget {
  final PfzPick pick;
  const ZoneDetailBottomSheet({super.key, required this.pick});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final pct = (pick.calibratedProbability * 100).round();
    final tier = ProbabilityTierX.fromPercent(pct);
    final tierColor = _tierColor(tier);
    final accent = speciesColor(pick.species);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSheet)),
        boxShadow: AppShadows.sheet,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.md, bottom: AppSpacing.sm),
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
                  // Species + rank + probability badge
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.14),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Icon(Icons.set_meal_rounded,
                            color: accent, size: 18),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              PfzSpecies.label(pick.species),
                              style: AppTextStyles.h2(locale)
                                  .copyWith(color: AppColors.fg1),
                            ),
                            Text(
                              l10n.pickRankForDay(pick.rank),
                              style: AppTextStyles.caption(locale)
                                  .copyWith(color: AppColors.fg3),
                            ),
                          ],
                        ),
                      ),
                      _ProbabilityBadge(tier: tier, color: tierColor),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  // Big suitability hero — deliberately NOT "catch probability":
                  // holdout AUC 0.62-0.79 by species, a real but modest signal.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$pct%',
                        style: AppTextStyles.display(locale)
                            .copyWith(color: tierColor),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l10n.suitability,
                          style: AppTextStyles.body(locale)
                              .copyWith(color: AppColors.fg3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.suitabilityDescription,
                    style: AppTextStyles.caption(locale)
                        .copyWith(color: AppColors.fg3),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  // Coordinates pill
                  _CoordChip(lat: pick.lat, lon: pick.lon),
                  if (pick.longRange) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _LongRangeNotice(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  // Stats
                  Row(
                    children: [
                      _StatTile(
                          icon: Icons.straighten_rounded,
                          value: '${pick.distCoastKm.toStringAsFixed(0)} km',
                          label: l10n.fromCoast),
                      const SizedBox(width: AppSpacing.sm),
                      _StatTile(
                          icon: Icons.history_rounded,
                          value: '${pick.historyCount}',
                          label: l10n.pastCatchesNearby),
                      const SizedBox(width: AppSpacing.sm),
                      _StatTile(
                          icon: Icons.emoji_events_outlined,
                          value: '#${pick.rank}',
                          label: l10n.rankToday),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: AppSpacing.base),
                  Row(
                    children: [
                      const Icon(Icons.satellite_alt_rounded,
                          size: 14, color: AppColors.fg3),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.pfzModelRefreshed(pick.modelVersion),
                        style: AppTextStyles.caption(locale)
                            .copyWith(color: AppColors.fg3),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: AppSpacing.base),
                  _TripPlanner(pick: pick),
                ],
              ),
            ),
          ),
          // Sticky CTA row
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cardLight,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                AppSpacing.lg, AppSpacing.lg + bottomInset),
            child: SeaLankaButton(
              label: l10n.navigateToZone,
              variant: SeaLankaButtonVariant.cta,
              icon: Icons.navigation_rounded,
              onPressed: () => _launchNavigation(pick),
            ),
          ),
        ],
      ),
    );
  }

  Color _tierColor(ProbabilityTier tier) => switch (tier) {
        ProbabilityTier.high => AppColors.probHigh2,
        ProbabilityTier.medium => AppColors.probMid2,
        ProbabilityTier.low => AppColors.probLow1,
      };
}

// geo: URI opens the device's default maps app (Google Maps on Android,
// Apple Maps on iOS both handle it) with a turn-by-turn destination — no
// API key, no map SDK dependency, just the platform's own handler.
Future<void> _launchNavigation(PfzPick pick) async {
  final uri =
      Uri.parse('geo:${pick.lat},${pick.lon}?q=${pick.lat},${pick.lon}');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _LongRangeNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.longRangeNotice,
              style:
                  AppTextStyles.caption(locale).copyWith(color: AppColors.fg1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbabilityBadge extends StatelessWidget {
  final ProbabilityTier tier;
  final Color color;
  const _ProbabilityBadge({required this.tier, required this.color});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final label = switch (tier) {
      ProbabilityTier.high => l10n.probabilityHigh,
      ProbabilityTier.medium => l10n.probabilityMedium,
      ProbabilityTier.low => l10n.probabilityLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.overline(locale).copyWith(color: color)),
        ],
      ),
    );
  }
}

class _CoordChip extends StatelessWidget {
  final double lat;
  final double lon;
  const _CoordChip({required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lon >= 0 ? 'E' : 'W';
    final text =
        '${lat.abs().toStringAsFixed(4)}° $ns, ${lon.abs().toStringAsFixed(4)}° $ew';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined,
              size: 14, color: AppColors.coralGold),
          const SizedBox(width: AppSpacing.sm),
          Text(text,
              style: AppTextStyles.body(locale).copyWith(color: AppColors.fg1)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile(
      {required this.icon, required this.label, required this.value});

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
            Text(value,
                style:
                    AppTextStyles.body(locale).copyWith(color: AppColors.fg1)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption(locale)
                    .copyWith(color: AppColors.fg3)),
          ],
        ),
      ),
    );
  }
}

/// Distance/fuel/ETA from the device's current position to this pick.
/// Loads location + the user's boat fuel/speed once on mount; falls back to
/// generic small-boat numbers when either isn't available (no GPS fix, or
/// the boat profile hasn't set fuel/speed — both optional fields).
class _TripPlanner extends StatefulWidget {
  final PfzPick pick;
  const _TripPlanner({required this.pick});

  @override
  State<_TripPlanner> createState() => _TripPlannerState();
}

class _TripPlannerState extends State<_TripPlanner> {
  bool _loading = true;
  double? _oneWayKm;
  double _fuelLph = _kDefaultFuelConsumptionLph;
  double _speedKnots = _kDefaultCruisingSpeedKnots;
  bool _roundTrip = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      sl<LocationService>().getCurrentPosition(),
      sl<GetProfileUseCase>()(),
    ]);
    if (!mounted) return;
    final position = results[0] as Position?;
    final profileResult = results[1] as dynamic;
    setState(() {
      if (position != null) {
        _oneWayKm = Geolocator.distanceBetween(position.latitude,
                position.longitude, widget.pick.lat, widget.pick.lon) /
            1000;
      }
      profileResult.fold((_) {}, (profile) {
        if (profile.fuelConsumptionLph != null) {
          _fuelLph = profile.fuelConsumptionLph;
        }
        if (profile.cruisingSpeedKnots != null) {
          _speedKnots = profile.cruisingSpeedKnots;
        }
      });
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_oneWayKm == null) {
      return Text(
        AppLocalizations.of(context)!.turnOnLocationHint,
        style: AppTextStyles.caption(locale).copyWith(color: AppColors.fg3),
      );
    }

    final distanceKm = _roundTrip ? _oneWayKm! * 2 : _oneWayKm!;
    final speedKmh = _speedKnots * _kKnotsToKmh;
    final hours = distanceKm / speedKmh;
    final fuelLiters = hours * _fuelLph;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.tripPlanner,
                style: AppTextStyles.caption(locale).copyWith(
                    color: AppColors.fg2, fontWeight: FontWeight.w600)),
            _TripModeToggle(
              roundTrip: _roundTrip,
              onChanged: (v) => setState(() => _roundTrip = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _StatTile(
                icon: Icons.straighten_rounded,
                value: '${distanceKm.toStringAsFixed(0)} km',
                label: _roundTrip
                    ? AppLocalizations.of(context)!.roundTrip
                    : AppLocalizations.of(context)!.oneWay),
            const SizedBox(width: AppSpacing.sm),
            _StatTile(
                icon: Icons.local_gas_station_outlined,
                value: '${fuelLiters.toStringAsFixed(1)} L',
                label: AppLocalizations.of(context)!.estFuel),
            const SizedBox(width: AppSpacing.sm),
            _StatTile(
                icon: Icons.schedule_rounded,
                value: _formatDuration(hours),
                label: AppLocalizations.of(context)!.estTime),
          ],
        ),
      ],
    );
  }

  String _formatDuration(double hours) {
    if (hours < 24) {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    final days = hours / 24;
    final d = days.floor();
    final remHours = ((days - d) * 24).round();
    return remHours == 0 ? '${d}d' : '${d}d ${remHours}h';
  }
}

class _TripModeToggle extends StatelessWidget {
  final bool roundTrip;
  final ValueChanged<bool> onChanged;
  const _TripModeToggle({required this.roundTrip, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
              label: AppLocalizations.of(context)!.oneWay,
              selected: !roundTrip,
              onTap: () => onChanged(false)),
          _ToggleOption(
              label: AppLocalizations.of(context)!.roundTrip,
              selected: roundTrip,
              onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleOption(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepSeaBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(label,
            style: AppTextStyles.caption(locale).copyWith(
                color: selected ? Colors.white : AppColors.fg3,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
