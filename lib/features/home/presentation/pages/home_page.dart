import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/attribution.dart';
import 'package:sea_lanka/core/widgets/loading_shimmer.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/core/widgets/section_title.dart';
import 'package:sea_lanka/features/home/domain/entities/fishing_condition.dart';
import 'package:sea_lanka/features/home/domain/entities/weather_summary.dart';
import 'package:sea_lanka/features/home/presentation/bloc/home_bloc.dart';

/// One day of the 10-day planning forecast (see sealanka-be's
/// GET /weather/forecast) — real Open-Meteo daily rollup, not our own
/// hourly aggregation.
class DailyForecastPoint {
  final DateTime date;
  final double windSpeedMaxKnots;
  final double windGustMaxKnots;
  final int windDirectionDeg;
  final double? waveHeightMaxM;
  final double rainChancePercent;
  final double precipitationSumMm;
  DailyForecastPoint({
    required this.date,
    required this.windSpeedMaxKnots,
    required this.windGustMaxKnots,
    required this.windDirectionDeg,
    required this.waveHeightMaxM,
    required this.rainChancePercent,
    required this.precipitationSumMm,
  });

  factory DailyForecastPoint.fromJson(Map<String, dynamic> json) =>
      DailyForecastPoint(
        date: DateTime.parse(json['date'] as String),
        windSpeedMaxKnots: (json['wind_speed_max_knots'] as num).toDouble(),
        windGustMaxKnots: (json['wind_gust_max_knots'] as num).toDouble(),
        windDirectionDeg: json['wind_direction_deg'] as int,
        waveHeightMaxM: (json['wave_height_max_m'] as num?)?.toDouble(),
        rainChancePercent: (json['rain_chance_percent'] as num).toDouble(),
        precipitationSumMm: (json['precipitation_sum_mm'] as num).toDouble(),
      );
}

// The backend's rain_chance_percent is a linear proxy off current precip
// rate (0 mm/hr -> 0%, >=2.5 mm/hr -> 100%, see sealanka-be's
// _rain_chance_percent), not a true probability -- a low value like 16%
// is trace/drizzle-level, not real rain. Used only as a fallback below when
// weather.weatherCode is unavailable (older backend / a field Open-Meteo
// temporarily omits).
const double _kRainingThresholdPercent = 30;

// weather.weatherCode is Open-Meteo's real WMO sky-condition classification
// (see sealanka-be's wind_service.get_wind_at_point docstring) -- added
// after a light 0.8mm/hr drizzle (which only just crosses the old
// precip-rate-only proxy's 30% "raining" threshold) showed the full rain
// overlay on an actually-just-overcast/gloomy day. WMO reference:
// https://open-meteo.com/en/docs -- 0/1 clear, 2/3 cloudy/overcast, 45/48
// fog, 51-57 drizzle, 61-67/80-82 rain, 71-77/85-86 snow (kept for
// completeness though irrelevant in Sri Lanka), 95-99 thunderstorm.
enum SkyCondition { clear, clearNight, cloudy, windy, rain, storm }

SkyCondition skyConditionFor(WeatherSummary weather, DateTime now) {
  final isNight = now.hour < 6 || now.hour >= 18;
  final code = weather.weatherCode;

  if (code != null) {
    if (code >= 95) {
      // WMO's thunderstorm code reflects storm activity/risk across the
      // model's wider grid cell, not necessarily an active storm directly
      // overhead -- corroborate with the actually-measured precip rate
      // (rainChancePercent) before showing the full storm treatment.
      // Verified against a real case: code 95 with only 32% measured rain
      // was genuinely just overcast/gloomy at that exact point, not
      // storming, despite the model's regional thunderstorm flag.
      final rain = weather.rainChancePercent ?? 0;
      return rain >= 50 ? SkyCondition.storm : SkyCondition.cloudy;
    }
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return SkyCondition.rain;
    }
    // Drizzle and fog read as "gloomy," not full rain -- lighter treatment.
    if ((code >= 51 && code <= 57) || code == 45 || code == 48) {
      return SkyCondition.cloudy;
    }
    if (code >= 71 && code <= 86) {
      return SkyCondition.rain; // snow -> n/a here, nearest visual
    }
    if (weather.windSpeedKnots >= 17) return SkyCondition.windy;
    if (code >= 2 || (weather.cloudCoverPercent ?? 0) >= 60) {
      return SkyCondition.cloudy;
    }
    return isNight ? SkyCondition.clearNight : SkyCondition.clear;
  }

  // Fallback for an older backend without weather_code.
  final rain = weather.rainChancePercent ?? 0;
  if (rain >= 70) return SkyCondition.storm;
  if (rain >= _kRainingThresholdPercent) return SkyCondition.rain;
  if (weather.windSpeedKnots >= 17) return SkyCondition.windy;
  return isNight ? SkyCondition.clearNight : SkyCondition.clear;
}

class _SkyVisual {
  final IconData icon;
  final List<Color> gradient;
  const _SkyVisual(this.icon, this.gradient);
}

const _skyVisuals = {
  SkyCondition.clear: _SkyVisual(
      Icons.wb_sunny_rounded, [Color(0xFFF4C430), AppColors.coralGold]),
  SkyCondition.clearNight: _SkyVisual(
      Icons.nightlight_round, [Color(0xFF1B2A4A), Color(0xFF3A4E7A)]),
  SkyCondition.cloudy:
      _SkyVisual(Icons.cloud_rounded, [Color(0xFF8A9BA8), Color(0xFF5E7080)]),
  SkyCondition.windy:
      _SkyVisual(Icons.air_rounded, [Color(0xFF6B8CAE), AppColors.marineBlue]),
  SkyCondition.rain: _SkyVisual(
      Icons.water_drop_rounded, [AppColors.marineBlue, Color(0xFF2C5D8F)]),
  SkyCondition.storm: _SkyVisual(
      Icons.thunderstorm_rounded, [Color(0xFF2C3E50), Color(0xFF0F1B2B)]),
};

Future<List<DailyForecastPoint>> _fetchDailyForecast(
    Dio dio, double lat, double lon) async {
  try {
    final response = await dio.get(ApiEndpoints.weatherForecast,
        queryParameters: {'lat': lat, 'lon': lon});
    return (response.data as List)
        .map((e) => DailyForecastPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException {
    return const [];
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeBloc _bloc;
  // 'Sri Lanka' until the real reverse-geocoded locality resolves (or
  // permanently, if geocoding fails/is unavailable) — never a hardcoded
  // city name unrelated to the device's actual position.
  String _locationLabel = 'Sri Lanka';
  List<DailyForecastPoint> _dailyForecast = const [];
  // Fetched independently of the point weather -- a fisherman's own
  // location can read calm while an island-wide system/DMC advisory (see
  // sealanka-be's coastal_scan_service.py / dmc_advisory_service.py) is
  // still active, so the home banner must not rely on local weather alone.
  int _activeAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _bloc = sl<HomeBloc>();
    _requestData();
    _loadActiveAlertCount();
  }

  Future<void> _requestData() async {
    final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
    if (!mounted) return;
    _bloc.add(HomeDataRequested(lat: lat, lon: lon));
    _resolveLocationLabel(lat, lon);
    final forecast = await _fetchDailyForecast(sl<Dio>(), lat, lon);
    if (mounted) setState(() => _dailyForecast = forecast);
  }

  Future<void> _loadActiveAlertCount() async {
    try {
      final response = await sl<Dio>().get(ApiEndpoints.safetyAlerts);
      final now = DateTime.now();
      final count =
          (response.data as List).cast<Map<String, dynamic>>().where((a) {
        final expiresAt = a['expires_at'] as String?;
        return expiresAt == null || DateTime.parse(expiresAt).isAfter(now);
      }).length;
      if (mounted) setState(() => _activeAlertCount = count);
    } catch (_) {
      // No banner boost if alerts can't be fetched -- never block the home page.
    }
  }

  Future<void> _resolveLocationLabel(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final label = place?.locality?.trim().isNotEmpty == true
          ? place!.locality!
          : place?.subAdministrativeArea?.trim().isNotEmpty == true
              ? place!.subAdministrativeArea!
              : null;
      if (label != null && mounted) setState(() => _locationLabel = label);
    } catch (_) {
      // No internet, geocoder unavailable, or coordinate resolves to
      // nothing (open ocean) — keep the 'Sri Lanka' fallback rather than
      // showing a stale or made-up place name.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: _HomeView(
        onRetry: _requestData,
        location: _locationLabel,
        dailyForecast: _dailyForecast,
        activeAlertCount: _activeAlertCount,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  final VoidCallback onRetry;
  final String location;
  final List<DailyForecastPoint> dailyForecast;
  final int activeAlertCount;
  const _HomeView(
      {required this.onRetry,
      required this.location,
      required this.dailyForecast,
      required this.activeAlertCount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BlocBuilder<HomeBloc, HomeState>(
            buildWhen: (prev, curr) => curr is HomeLoaded || curr is HomeError,
            builder: (context, state) {
              final sky = state is HomeLoaded
                  ? skyConditionFor(state.weather, DateTime.now())
                  : SkyCondition.clear;
              return _HomeHeader(location: location, sky: sky);
            },
          ),
          Transform.translate(
            offset: const Offset(0, -AppSpacing.xl2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                0,
                AppSpacing.pagePadding,
                AppSpacing.xl2,
              ),
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeError) {
                    return _ErrorView(message: state.message, onRetry: onRetry);
                  }
                  if (state is HomeLoaded) {
                    return _LoadedBody(
                      weather: state.weather,
                      condition: state.condition,
                      dailyForecast: dailyForecast,
                      activeAlertCount: activeAlertCount,
                    );
                  }
                  return const _LoadingBody();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home hero header — matches `.header` in home-dashboard.html exactly:
/// logo + location pill on one row, greeting + sunrise icon below, date
/// below that. Bell/avatar ride along the top row since they're the app's
/// only entry points to Alerts/Profile (see CLAUDE.md feature map).
class _HomeHeader extends StatelessWidget {
  final String location;
  final SkyCondition sky;
  const _HomeHeader({required this.location, required this.sky});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final l10n = AppLocalizations.of(context)!;
    final greeting = hour < 12
        ? l10n.goodMorningGreeting
        : hour < 17
            ? l10n.goodAfternoonGreeting
            : l10n.goodEveningGreeting;
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final locale = Localizations.localeOf(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppSpacing.radiusXl),
      ),
      child: CustomPaint(
        painter: _HeaderWavePainter(),
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl3,
          ),
          child: Stack(
            children: [
              // Behind the greeting only, not the whole header -- a subtle
              // touch tied to real conditions, not decoration for its own
              // sake. One overlay per SkyCondition; clear/clearNight get
              // their own lightweight stars-only treatment, no overlay for
              // plain clear daytime.
              if (sky == SkyCondition.rain)
                const Positioned.fill(child: _RainfallOverlay())
              else if (sky == SkyCondition.storm)
                const Positioned.fill(child: _StormOverlay())
              else if (sky == SkyCondition.windy)
                const Positioned.fill(child: _WindyOverlay())
              else if (sky == SkyCondition.clearNight)
                const Positioned.fill(child: _StarsOverlay())
              else if (sky == SkyCondition.cloudy)
                const Positioned.fill(child: _CloudyOverlay()),
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Image.asset(
                            'assets/images/logo/logo-sealanka-transparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Spacer(),
                        _LiveLocationPill(location: location),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip:
                              AppLocalizations.of(context)!.safetyAlertsTooltip,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => context.go(AppRoutes.alerts),
                          icon: const Icon(Icons.notifications_outlined,
                              color: AppColors.fgOnDark, size: 20),
                        ),
                        _ProfileAvatarButton(
                            onTap: () => context.go(AppRoutes.profile)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Text(
                          greeting,
                          style: AppTextStyles.display(locale)
                              .copyWith(color: AppColors.fgOnDark),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Icon(_skyVisuals[sky]!.icon,
                            color: sky == SkyCondition.rain ||
                                    sky == SkyCondition.storm ||
                                    sky == SkyCondition.cloudy
                                ? AppColors.skyBlue
                                : AppColors.coralGold,
                            size: 22),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: AppTextStyles.body(locale)
                          .copyWith(color: AppColors.fgOnDark2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Falling-rain effect behind the greeting, shown only when
/// weather.rainChancePercent >= _kRainingThresholdPercent. Plain animated lines (no per-drop blur/
/// shadow layers) -- a blurred layer per marker is what crashed the marine
/// traffic map's renderer at scale, so this stays cheap even though it's
/// only ~30 drops here.
class _RainfallOverlay extends StatefulWidget {
  const _RainfallOverlay();

  @override
  State<_RainfallOverlay> createState() => _RainfallOverlayState();
}

class _RainfallOverlayState extends State<_RainfallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  // Fixed per-drop x position (0-1) and speed/length variation, generated
  // once -- deterministic seed so it doesn't reshuffle every rebuild.
  final List<_Raindrop> _drops =
      List.generate(30, (i) => _Raindrop.forIndex(i));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter:
                _RainfallPainter(progress: _controller.value, drops: _drops),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Raindrop {
  final double x; // 0-1, fraction of width
  final double speed; // relative fall speed
  final double length; // streak length in px
  final double phase; // 0-1 offset so drops don't fall in lockstep

  _Raindrop(
      {required this.x,
      required this.speed,
      required this.length,
      required this.phase});

  factory _Raindrop.forIndex(int i) {
    // Cheap deterministic pseudo-randomness -- no need for dart:math Random
    // (and its associated seeded-state ceremony) for a purely decorative effect.
    final h = (i * 2654435761) & 0xFFFFFFFF;
    final x = ((h & 0xFF) / 0xFF);
    final speed = 0.7 + (((h >> 8) & 0xFF) / 0xFF) * 0.6;
    final length = 10.0 + (((h >> 16) & 0xFF) / 0xFF) * 10.0;
    final phase = ((h >> 24) & 0xFF) / 0xFF;
    return _Raindrop(x: x, speed: speed, length: length, phase: phase);
  }
}

class _RainfallPainter extends CustomPainter {
  final double progress;
  final List<_Raindrop> drops;
  _RainfallPainter({required this.progress, required this.drops});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final drop in drops) {
      final t = (progress * drop.speed + drop.phase) % 1.0;
      final dx = drop.x * size.width;
      final dy = t * (size.height + drop.length) - drop.length;
      canvas.drawLine(Offset(dx, dy), Offset(dx - 3, dy + drop.length), paint);
    }
  }

  @override
  bool shouldRepaint(_RainfallPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Heavy-rain effect (weather.rainChancePercent >= 70) -- the same falling
/// lines as [_RainfallOverlay] but denser/faster, plus an irregular white
/// flash standing in for lightning. Separate controller for the flash so
/// its irregular timing doesn't disturb the rain's steady fall.
class _StormOverlay extends StatefulWidget {
  const _StormOverlay();

  @override
  State<_StormOverlay> createState() => _StormOverlayState();
}

class _StormOverlayState extends State<_StormOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _rainController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..repeat();
  late final AnimationController _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  final List<_Raindrop> _drops =
      List.generate(45, (i) => _Raindrop.forIndex(i));
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _scheduleFlash();
  }

  void _scheduleFlash() {
    // Irregular 2.5-6s gap between flashes -- a fixed interval reads as a
    // strobe, not lightning. Cheap deterministic jitter off the current
    // millisecond, same reasoning as _Raindrop.forIndex's pseudo-randomness.
    final jitterMs = 2500 + (DateTime.now().millisecondsSinceEpoch % 3500);
    _flashTimer = Timer(Duration(milliseconds: jitterMs), () {
      if (!mounted) return;
      _flashController.forward(from: 0).then((_) {
        if (mounted) _flashController.reverse();
      });
      _scheduleFlash();
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _rainController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _rainController,
            builder: (context, _) => CustomPaint(
              painter: _RainfallPainter(
                  progress: _rainController.value, drops: _drops),
              size: Size.infinite,
            ),
          ),
          AnimatedBuilder(
            animation: _flashController,
            builder: (context, _) => Container(
              color: Colors.white.withOpacity(_flashController.value * 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gust-lines effect (SkyCondition.windy, wind >=17kn -- the backend's own
/// fresh/strong boundary) -- longer, faster, more horizontal streaks than
/// rain, evoking wind rather than falling water.
class _WindyOverlay extends StatefulWidget {
  const _WindyOverlay();

  @override
  State<_WindyOverlay> createState() => _WindyOverlayState();
}

class _WindyOverlayState extends State<_WindyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  final List<_Raindrop> _gusts =
      List.generate(14, (i) => _Raindrop.forIndex(i));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _GustPainter(progress: _controller.value, gusts: _gusts),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GustPainter extends CustomPainter {
  final double progress;
  final List<_Raindrop> gusts;
  _GustPainter({required this.progress, required this.gusts});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final gust in gusts) {
      final t = (progress * gust.speed + gust.phase) % 1.0;
      final dy = gust.x * size.height;
      final dx = t * (size.width + 40) - 40;
      canvas.drawLine(
          Offset(dx, dy), Offset(dx - gust.length * 2, dy - 4), paint);
    }
  }

  @override
  bool shouldRepaint(_GustPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Twinkling stars (SkyCondition.clearNight, hour < 6 or >= 18) -- fixed
/// positions, per-star opacity pulses on its own phase so they don't blink
/// in unison.
class _StarsOverlay extends StatefulWidget {
  const _StarsOverlay();

  @override
  State<_StarsOverlay> createState() => _StarsOverlayState();
}

class _StarsOverlayState extends State<_StarsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  final List<_Raindrop> _stars =
      List.generate(18, (i) => _Raindrop.forIndex(i));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _StarsPainter(progress: _controller.value, stars: _stars),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final double progress;
  final List<_Raindrop> stars;
  _StarsPainter({required this.progress, required this.stars});

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final t = (progress + star.phase) % 1.0;
      final opacity = 0.25 + 0.55 * (0.5 - (t - 0.5).abs()) * 2;
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity.clamp(0.0, 0.8));
      final dx = star.x * size.width;
      final dy = (star.speed - 0.7) / 0.6 * size.height * 0.8;
      canvas.drawCircle(Offset(dx, dy), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Slow drifting cloud puffs (SkyCondition.cloudy -- overcast/drizzle/fog,
/// see skyConditionFor's WMO code mapping) -- soft overlapping ellipses,
/// no blur (see _RainfallOverlay's docstring for why that's avoided here).
class _CloudyOverlay extends StatefulWidget {
  const _CloudyOverlay();

  @override
  State<_CloudyOverlay> createState() => _CloudyOverlayState();
}

class _CloudyOverlayState extends State<_CloudyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  final List<_Raindrop> _puffs = List.generate(4, (i) => _Raindrop.forIndex(i));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _CloudyPainter(progress: _controller.value, puffs: _puffs),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CloudyPainter extends CustomPainter {
  final double progress;
  final List<_Raindrop> puffs;
  _CloudyPainter({required this.progress, required this.puffs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.07);
    for (final puff in puffs) {
      final t = (progress * (puff.speed * 0.3) + puff.phase) % 1.0;
      final dx = t * (size.width + 100) - 50;
      final dy = puff.x * size.height * 0.7;
      final r = 20.0 + puff.length;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(dx, dy), width: r * 2.4, height: r),
          paint);
    }
  }

  @override
  bool shouldRepaint(_CloudyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LiveLocationPill extends StatelessWidget {
  final String location;
  const _LiveLocationPill({required this.location});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined,
              size: 13, color: AppColors.fgOnDark),
          const SizedBox(width: 4),
          Text(location,
              style: AppTextStyles.caption(locale).copyWith(
                  color: AppColors.fgOnDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ProfileAvatarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.profileTooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.fishGradient,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.person_rounded,
            color: AppColors.fgOnDark, size: 18),
      ),
    );
  }
}

/// Subtle wave line, ~8% white, matching `.header__wave` in the design.
class _HeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.94)
      ..cubicTo(w * 0.25, h * 0.86, w * 0.5, h * 1.0, w * 0.75, h * 0.90)
      ..cubicTo(w * 0.875, h * 0.85, w * 0.95, h * 0.95, w, h * 0.90)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoadedBody extends StatelessWidget {
  final WeatherSummary weather;
  final FishingCondition condition;
  final List<DailyForecastPoint> dailyForecast;
  final int activeAlertCount;
  const _LoadedBody(
      {required this.weather,
      required this.condition,
      required this.dailyForecast,
      required this.activeAlertCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ForecastCard(weather: weather, condition: condition),
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(
          title: AppLocalizations.of(context)!.fishingZonesSection,
          actionLabel: AppLocalizations.of(context)!.seeAll,
          onAction: () => context.go(AppRoutes.pfz),
        ),
        const SizedBox(height: AppSpacing.md),
        _MiniMapCard(onTap: () => context.go(AppRoutes.pfz)),
        if (_AdvisoryBanner.isNotable(weather) || activeAlertCount > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          _AdvisoryBanner(weather: weather, activeAlertCount: activeAlertCount),
        ],
        const SizedBox(height: AppSpacing.lg),
        _InfoPillsRow(weather: weather),
        if (dailyForecast.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(title: AppLocalizations.of(context)!.tenDayForecast),
          const SizedBox(height: AppSpacing.md),
          _TenDayForecastStrip(days: dailyForecast),
        ],
        const SizedBox(height: AppSpacing.xl),
        const Attribution(),
      ],
    );
  }
}

/// Horizontal strip of daily planning cards -- wind, waves, rain per day
/// for the next 10 days, so a fisherman can pick which days are worth
/// heading out rather than only ever seeing today.
class _TenDayForecastStrip extends StatelessWidget {
  final List<DailyForecastPoint> days;
  const _TenDayForecastStrip({required this.days});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final day = days[i];
          final isToday = i == 0;
          final heavyRain = day.rainChancePercent >= 70;
          return Container(
            width: 108,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: AppShadows.card,
              border: isToday
                  ? Border.all(color: AppColors.coralGold, width: 1.5)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isToday
                        ? AppLocalizations.of(context)!.today
                        : DateFormat('EEE').format(day.date),
                    style: AppTextStyles.caption(locale).copyWith(
                        color: isToday ? AppColors.coralGold : AppColors.fg3,
                        fontWeight: FontWeight.w700)),
                Text(DateFormat('d MMM').format(day.date),
                    style: AppTextStyles.overline(locale)
                        .copyWith(color: AppColors.fg3)),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  const Icon(Icons.air_rounded,
                      size: 14, color: AppColors.marineBlue),
                  const SizedBox(width: 4),
                  Text('${day.windSpeedMaxKnots.toStringAsFixed(0)} kn',
                      style: AppTextStyles.caption(locale)
                          .copyWith(color: AppColors.fg1)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.waves_rounded,
                      size: 14, color: AppColors.marineBlue),
                  const SizedBox(width: 4),
                  Text(
                      day.waveHeightMaxM != null
                          ? '${day.waveHeightMaxM!.toStringAsFixed(1)} m'
                          : '',
                      style: AppTextStyles.caption(locale)
                          .copyWith(color: AppColors.fg1)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.water_drop_rounded,
                      size: 14,
                      color:
                          heavyRain ? AppColors.danger : AppColors.marineBlue),
                  const SizedBox(width: 4),
                  Text('${day.rainChancePercent.toStringAsFixed(0)}%',
                      style: AppTextStyles.caption(locale).copyWith(
                          color: heavyRain ? AppColors.danger : AppColors.fg1)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Today's forecast" — green fishing-quality badge + hero temp + 3-metric
/// row (Wind / Waves / Rain). Matches `.card` + `.forecast__*` in the design.
class _ForecastCard extends StatelessWidget {
  final WeatherSummary weather;
  final FishingCondition condition;
  const _ForecastCard({required this.weather, required this.condition});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final windDir = _compass(weather.windDirectionDeg);
    final badgeColor = _badgeColor(condition.level);
    final badgeLabel = _badgeLabel(l10n, condition.level);
    final sky = _skyVisuals[skyConditionFor(weather, DateTime.now())]!;

    return SeaLankaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.todaysForecast,
                style: AppTextStyles.caption(locale).copyWith(
                    color: AppColors.fg2, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(badgeLabel,
                        style: AppTextStyles.caption(locale).copyWith(
                            color: badgeColor, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  // Same 5-state SkyCondition as the header (see
                  // skyConditionFor) instead of a sun/rain-only binary that
                  // always showed a sun even during real heavy rain.
                  gradient: LinearGradient(
                    colors: sky.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(sky.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.base),
              // Null inland (marine data only covers ocean points, e.g.
              // Open-Meteo's marine API has nothing at a landlocked city)
              // -- a dash reads as "no data here" instead of a blank gap
              // that looks broken.
              weather.seaTempC != null
                  ? _CountUpText(
                      target: weather.seaTempC!,
                      decimals: 0,
                      style: AppTextStyles.display(locale).copyWith(
                          color: AppColors.fg1, fontSize: 44, height: 1),
                    )
                  : Text('-',
                      style: AppTextStyles.display(locale).copyWith(
                          color: AppColors.fg1, fontSize: 44, height: 1)),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('°C',
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fg1)),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather.condition,
                        style: AppTextStyles.body(locale).copyWith(
                            color: AppColors.fg1, fontWeight: FontWeight.w700)),
                    if (weather.seaTempC != null)
                      Text(
                          l10n.feelsLike(
                              (weather.seaTempC! + 2).toStringAsFixed(0)),
                          style: AppTextStyles.caption(locale)
                              .copyWith(color: AppColors.fg2)),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
          Row(
            children: [
              Expanded(
                child: _AnimatedMetricTile(
                  // A rotating compass needle instead of a static icon --
                  // weather.windDirectionDeg was only ever shown as text
                  // ("SW") before, never visually.
                  leading:
                      _CompassNeedle(directionDeg: weather.windDirectionDeg),
                  value: _CountUpText(
                    target: weather.windSpeedKnots,
                    decimals: 0,
                    suffix: ' kn',
                    style:
                        AppTextStyles.h3(locale).copyWith(color: AppColors.fg1),
                  ),
                  label: l10n.windLabel(windDir),
                ),
              ),
              Expanded(
                child: _AnimatedMetricTile(
                  leading: const Icon(Icons.waves_rounded,
                      size: 20, color: AppColors.marineBlue),
                  value: weather.waveHeightM != null
                      ? _CountUpText(
                          target: weather.waveHeightM!,
                          decimals: 1,
                          suffix: ' m',
                          style: AppTextStyles.h3(locale)
                              .copyWith(color: AppColors.fg1),
                        )
                      : Text('-',
                          style: AppTextStyles.h3(locale)
                              .copyWith(color: AppColors.fg1)),
                  label: l10n.wavesLabel,
                ),
              ),
              Expanded(
                child: _AnimatedMetricTile(
                  leading: const Icon(Icons.water_drop_outlined,
                      size: 20, color: AppColors.marineBlue),
                  value: weather.rainChancePercent != null
                      ? _CountUpText(
                          target: weather.rainChancePercent!,
                          decimals: 0,
                          suffix: ' %',
                          style: AppTextStyles.h3(locale)
                              .copyWith(color: AppColors.fg1),
                        )
                      : Text('-',
                          style: AppTextStyles.h3(locale)
                              .copyWith(color: AppColors.fg1)),
                  label: l10n.rainLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _badgeColor(FishingConditionLevel level) => switch (level) {
        FishingConditionLevel.excellent ||
        FishingConditionLevel.good =>
          AppColors.success,
        FishingConditionLevel.fair => AppColors.warning,
        FishingConditionLevel.poor => AppColors.danger,
      };

  String _badgeLabel(AppLocalizations l10n, FishingConditionLevel level) =>
      switch (level) {
        FishingConditionLevel.excellent ||
        FishingConditionLevel.good =>
          l10n.goodFishing,
        FishingConditionLevel.fair => l10n.fairFishing,
        FishingConditionLevel.poor => l10n.poorFishing,
      };

  String _compass(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[(((deg % 360) / 45).round()) % 8];
  }
}

/// Same icon/value/label shape as the shared MetricTile (core/widgets/
/// metric_tile.dart, still used elsewhere e.g. profile stats), but takes
/// widgets instead of a plain icon/String so the wind tile's leading can be
/// an animated [_CompassNeedle] and every value can count up with
/// [_CountUpText] -- kept local to this file rather than widening
/// MetricTile's shared contract for one screen's animation.
class _AnimatedMetricTile extends StatelessWidget {
  final Widget leading;
  final Widget value;
  final String label;
  const _AnimatedMetricTile(
      {required this.leading, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(height: AppSpacing.sm),
        value,
        const SizedBox(height: 2),
        Text(label,
            style:
                AppTextStyles.caption(locale).copyWith(color: AppColors.fg3)),
      ],
    );
  }
}

/// Counts up from 0 to [target] once on first build (a fresh weather
/// reading landing should read as "just arrived," not a static number that
/// was always there) -- runs once, not on every rebuild, since AnimatedX
/// widgets re-animate on every value change and a live weather refresh
/// updating mid-count would look like flickering, not a fresh reading.
class _CountUpText extends StatefulWidget {
  final double target;
  final int decimals;
  final String suffix;
  final TextStyle style;
  const _CountUpText({
    required this.target,
    required this.decimals,
    this.suffix = '',
    required this.style,
  });

  @override
  State<_CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<_CountUpText> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.target),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
          '${value.toStringAsFixed(widget.decimals)}${widget.suffix}',
          style: widget.style),
    );
  }
}

/// Small compass rose with a needle that rotates to [directionDeg] on
/// first build, animating in from due north rather than appearing
/// pre-rotated -- the only place windDirectionDeg was ever shown before
/// this was the "SW"-style text label, never visually.
class _CompassNeedle extends StatefulWidget {
  final double directionDeg;
  const _CompassNeedle({required this.directionDeg});

  @override
  State<_CompassNeedle> createState() => _CompassNeedleState();
}

class _CompassNeedleState extends State<_CompassNeedle> {
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    // Kicks off the AnimatedRotation below a frame after first build --
    // starting at 0 and animating to the real angle, not appearing
    // pre-rotated with no motion at all.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _angle = widget.directionDeg * math.pi / 180);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.explore_outlined, size: 20, color: AppColors.marineBlue),
          AnimatedRotation(
            turns: _angle / (2 * math.pi),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.navigation_rounded,
                size: 11, color: AppColors.marineBlue),
          ),
        ],
      ),
    );
  }
}

// Simple equirectangular bbox covering Sri Lanka's EEZ plus nearby reach
// (matches the PFZ PDF export's own bbox at core/pfz's REACH_KM) -- used
// only to place the mini-map's decorative bubbles roughly where a pick
// actually is, not for precision navigation.

/// Dark schematic EEZ mini-map with floating probability-tier zone bubbles —
/// a lightweight CustomPaint illustration, not a live tile map. Matches
/// `.mapcard` in home-dashboard.html. The real interactive map
/// (OpenStreetMap via flutter_map) lives on the full PFZ screen this card
/// links to.
class _MiniMapCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MiniMapCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          // LayoutBuilder is hoisted to *this* level so every Positioned
          // below is a direct Stack child — nesting a LayoutBuilder inside
          // each bubble instead breaks Stack's positioning entirely (all
          // bubbles collapse to the top-left corner).
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapSize = constraints.biggest;
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0D2040), AppColors.midnightNavy],
                        ),
                      ),
                      child: CustomPaint(painter: _MiniMapPainter()),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: _MapGlassPill(
                        label:
                            AppLocalizations.of(context)!.sriLankaRangeLabel),
                  ),
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.midnightNavy.withOpacity(0.55),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.open_in_full_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  _ZoneBubble(
                      percent: 85,
                      left: 0.572,
                      top: 0.294,
                      size: 44,
                      mapSize: mapSize),
                  _ZoneBubble(
                      percent: 60,
                      left: 0.698,
                      top: 0.485,
                      size: 36,
                      mapSize: mapSize),
                  _ZoneBubble(
                      percent: 25,
                      left: 0.413,
                      top: 0.823,
                      size: 30,
                      mapSize: mapSize),
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_rounded,
                              size: 14, color: AppColors.midnightNavy),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context)!.viewFullMap,
                              style: AppTextStyles.caption(locale).copyWith(
                                  color: AppColors.midnightNavy,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapGlassPill extends StatelessWidget {
  final String label;
  const _MapGlassPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(label,
          style: AppTextStyles.caption(locale)
              .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _ZoneBubble extends StatelessWidget {
  final int percent;
  final double left;
  final double top;
  final double size;
  final Size mapSize;
  const _ZoneBubble({
    required this.percent,
    required this.left,
    required this.top,
    required this.size,
    required this.mapSize,
  });

  Color get _color {
    if (percent >= 70) return AppColors.probHigh1;
    if (percent >= 40) return AppColors.probMid2;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: mapSize.width * left - size / 2,
      top: mapSize.height * top - size / 2,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [_color.withOpacity(0.9), _color.withOpacity(0.15)],
            stops: const [0.0, 1.0],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.55)),
        ),
        child: Text(
          '$percent',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: size > 40 ? 13 : 11,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Renders the real Sri Lanka landmass + EEZ boundary, using the
/// pre-simplified path data shipped in the design system's
/// `sl-map-data.js` (`MAP_MINI`, 358×201 viewBox) — the same accurate
/// geography used across the design's screens, not a placeholder grid.
class _MiniMapPainter extends CustomPainter {
  static const double _vw = 358, _vh = 201;

  static final List<List<Offset>> _eezPaths = _parseSubpaths(
      'M 76.0,50.2 L 74.5,42.5 L 66.9,33.4 L 78.6,25.1 L 107.0,20.8 L 145.9,7.4 L 161.5,3.1 L 212.1,-7.2 L 239.0,-13.8 L 295.6,-19.2 L 307.5,-11.1 L 317.6,-2.5 L 329.2,5.5 L 344.7,18.1 L 354.3,27.9 L 361.8,38.1 L 371.0,46.2 L 379.4,55.4 L 385.7,64.3 L 393.4,78.4 L 397.4,89.4 L 399.1,100.2 L 399.5,115.6 L 396.7,128.9 L 390.4,144.0 L 383.3,155.4 L 371.4,169.7 L 355.6,183.3 L 340.1,193.5 L 321.0,203.4 L 303.7,210.7 L 273.3,221.5 L 253.1,226.9 L 210.8,235.7 L 189.5,239.3 L 173.6,241.4 L 153.2,243.0 L 133.0,243.4 L 113.8,242.7 L 90.5,240.7 L 61.8,236.7 L 43.0,233.1 L 23.6,228.2 L 5.3,222.2 L -15.6,213.5 L -30.2,206.1 L -45.0,196.8 L -58.0,186.4 L -66.9,177.6 L -20.2,144.9 L 0.2,126.7 L 31.9,94.9 L 41.1,71.8 L 49.9,67.4 L 62.7,63.1 L 73.2,56.3 L 76.0,50.2 Z');

  static final List<List<Offset>> _landPaths = _parseSubpaths(
      'M 121.7,32.4 L 117.7,28.3 L 103.4,28.4 L 93.3,30.2 L 87.9,33.3 L 87.9,35.4 L 89.6,36.4 L 94.2,37.0 L 96.3,36.1 L 104.4,36.3 L 108.4,37.6 L 109.3,39.2 L 103.8,41.9 L 103.9,43.6 L 106.9,44.9 L 107.3,46.8 L 102.2,52.1 L 99.3,53.0 L 95.6,50.4 L 89.9,49.5 L 85.3,49.7 L 81.9,50.5 L 78.8,50.2 L 77.8,50.7 L 80.3,51.5 L 86.5,51.6 L 90.2,52.5 L 97.0,56.7 L 96.3,58.9 L 98.8,61.1 L 95.7,65.9 L 92.0,68.7 L 90.4,66.2 L 88.7,67.7 L 89.7,70.8 L 83.9,76.3 L 84.4,81.3 L 90.1,91.9 L 88.9,93.6 L 89.4,96.2 L 92.6,104.3 L 90.9,106.5 L 94.2,112.7 L 90.9,113.5 L 90.9,114.5 L 92.4,115.1 L 99.4,125.9 L 99.1,127.9 L 101.2,129.7 L 104.5,135.8 L 108.3,139.7 L 114.2,141.7 L 121.9,143.4 L 134.6,144.7 L 143.0,143.8 L 153.9,140.5 L 172.1,137.6 L 182.3,135.3 L 190.5,132.4 L 199.6,127.8 L 207.1,120.1 L 210.0,111.7 L 209.3,108.0 L 210.0,103.0 L 203.6,92.8 L 196.2,88.0 L 193.3,87.0 L 193.8,85.4 L 190.9,83.8 L 191.9,82.8 L 189.7,82.4 L 187.6,81.1 L 185.3,78.4 L 178.7,66.9 L 176.1,66.9 L 172.5,67.9 L 174.0,66.4 L 172.7,63.7 L 165.6,57.4 L 162.7,56.8 L 156.3,52.2 L 150.4,44.8 L 121.7,32.4 Z');

  /// Parses an SVG path string containing only `M`/`L`/`Z` absolute commands
  /// (which is all the design's pre-simplified geo paths use) into a list
  /// of point-subpaths, one per `M...Z` segment.
  static List<List<Offset>> _parseSubpaths(String d) {
    final subpaths = <List<Offset>>[];
    List<Offset>? current;
    for (final token in d.trim().split(RegExp(r'\s+(?=[MLZ])'))) {
      final cmd = token[0];
      if (cmd == 'Z') {
        if (current != null) subpaths.add(current);
        current = null;
        continue;
      }
      final coords = token.substring(1).trim().split(',');
      final point = Offset(double.parse(coords[0]), double.parse(coords[1]));
      if (cmd == 'M') {
        if (current != null) subpaths.add(current);
        current = [point];
      } else {
        current?.add(point);
      }
    }
    if (current != null) subpaths.add(current);
    return subpaths;
  }

  Path _buildPath(List<List<Offset>> subpaths, double sx, double sy) {
    final path = Path();
    for (final sub in subpaths) {
      if (sub.isEmpty) continue;
      path.moveTo(sub.first.dx * sx, sub.first.dy * sy);
      for (final p in sub.skip(1)) {
        path.lineTo(p.dx * sx, p.dy * sy);
      }
      path.close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vw;
    final sy = size.height / _vh;

    final eezPaint = Paint()
      ..color = AppColors.skyBlue.withOpacity(0.14)
      ..style = PaintingStyle.fill;
    final eezStroke = Paint()
      ..color = AppColors.skyBlue.withOpacity(0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final eezPath = _buildPath(_eezPaths, sx, sy);
    canvas.drawPath(eezPath, eezPaint);
    canvas.drawPath(eezPath, eezStroke);

    final landPaint = Paint()
      ..color = const Color(0xFF192C45)
      ..style = PaintingStyle.fill;
    final landStroke = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final landPath = _buildPath(_landPaths, sx, sy);
    canvas.drawPath(landPath, landPaint);
    canvas.drawPath(landPath, landStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Amber weather-advisory banner — matches `.advisory` in the design.
/// Real-conditions warning — only shown when today's actual wind/wave/rain
/// reading crosses a notable threshold, built from the live numbers
/// already on the card above. GFS's single "now" reading gives no future
/// trend to warn about, so this deliberately doesn't claim a specific time
/// ("winds increase after 4pm") the way the old hardcoded copy did — that
/// was never real data, just placeholder text.
class _AdvisoryBanner extends StatelessWidget {
  final WeatherSummary weather;
  final int activeAlertCount;
  const _AdvisoryBanner({required this.weather, this.activeAlertCount = 0});

  // Wind threshold matches the backend's own "fresh" classification
  // boundary (sealanka-be's _wind_condition: >=17kn -> fresh/strong).
  static bool isNotable(WeatherSummary w) =>
      w.windSpeedKnots >= 17 ||
      (w.waveHeightM ?? 0) >= 2.0 ||
      (w.rainChancePercent ?? 0) >= 60;

  String _message(AppLocalizations l10n) {
    final parts = <String>[];
    if (weather.windSpeedKnots >= 17) {
      parts.add(l10n.advisoryWindPart(
          weather.windSpeedKnots.toStringAsFixed(0), weather.condition));
    }
    if ((weather.waveHeightM ?? 0) >= 2.0) {
      parts
          .add(l10n.advisoryWavesPart(weather.waveHeightM!.toStringAsFixed(1)));
    }
    if ((weather.rainChancePercent ?? 0) >= 60) {
      parts.add(
          l10n.advisoryRainPart(weather.rainChancePercent!.toStringAsFixed(0)));
    }

    // A system/DMC advisory can be active island-wide even when this
    // fisherman's own point reads calm -- say so explicitly rather than
    // only ever describing the local numbers.
    if (activeAlertCount > 0) {
      final advisoryPhrase = activeAlertCount == 1
          ? l10n.advisoryPhraseSingular
          : l10n.advisoryPhrasePlural(activeAlertCount);
      if (parts.isEmpty) {
        final message = l10n.advisoryEmptyMessage(advisoryPhrase);
        return message[0].toUpperCase() + message.substring(1);
      }
      parts.add(advisoryPhrase);
    }

    final body = l10n.advisoryMessage(parts.join(', '));
    return body[0].toUpperCase() + body.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border(
          left: BorderSide(color: AppColors.warning, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.18),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFF8A6300), size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.weatherAdvisoryTitle,
                    style: AppTextStyles.overline(locale)
                        .copyWith(color: const Color(0xFF6F4A00))),
                const SizedBox(height: 2),
                Text(
                  _message(l10n),
                  style:
                      AppTextStyles.body(locale).copyWith(color: AppColors.fg1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info pills -- Visibility, Pressure, High tide (every WeatherSummary
/// field not already surfaced on the forecast card above). Each fades +
/// slides in on a staggered delay rather than popping in all at once.
class _InfoPillsRow extends StatelessWidget {
  final WeatherSummary weather;
  const _InfoPillsRow({required this.weather});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pills = [
      _InfoPill(
        icon: Icons.visibility_outlined,
        label: l10n.visibility,
        value: weather.visibilityKm != null
            ? '${weather.visibilityKm!.toStringAsFixed(1)} km'
            : '',
      ),
      _InfoPill(
        icon: Icons.speed_rounded,
        label: l10n.pressureLabel,
        value: weather.pressureHpa != null
            ? '${weather.pressureHpa!.toStringAsFixed(0)} hPa'
            : '',
      ),
      _InfoPill(
        icon: Icons.waves_rounded,
        label: l10n.highTide,
        value: weather.highTideLabel ?? '',
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: _StaggeredEntrance(index: i, child: pills[i])),
        ],
      ],
    );
  }
}

/// Fade + slide-up entrance, delayed by [index] * 80ms -- a staggered
/// reveal instead of every pill appearing simultaneously.
class _StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredEntrance({required this.index, required this.child});

  @override
  State<_StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<_StaggeredEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.25),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoPill(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SeaLankaCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, size: 16, color: AppColors.deepSeaBlue),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label,
              style: AppTextStyles.caption(locale)
                  .copyWith(color: AppColors.fg3, fontSize: 10)),
          Text(value,
              style: AppTextStyles.h3(locale)
                  .copyWith(color: AppColors.fg1, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        ShimmerCard(),
        SizedBox(height: AppSpacing.lg),
        LoadingShimmer(height: 160, borderRadius: 16),
        SizedBox(height: AppSpacing.lg),
        LoadingShimmer(height: 80, borderRadius: 14),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.fg3),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(locale).copyWith(color: AppColors.fg2),
          ),
          const SizedBox(height: AppSpacing.base),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }
}
