import 'dart:math' as math;

import 'package:dio/dio.dart';
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
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/attribution.dart';
import 'package:sea_lanka/features/solunar/data/datasources/solunar_remote_datasource.dart';
import 'package:sea_lanka/features/solunar/data/repositories/solunar_repository_impl.dart';
import 'package:sea_lanka/features/solunar/domain/entities/lunar_data.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solar_data.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_period.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_snapshot.dart';
import 'package:sea_lanka/features/solunar/domain/usecases/get_solunar_usecase.dart';
import 'package:sea_lanka/features/solunar/presentation/bloc/solunar_bloc.dart';

/// Sol-Lunar screen — full dark theme per design spec.
class SolunarPage extends StatelessWidget {
  const SolunarPage({super.key});

  static const _bgDark = AppColors.midnightNavy;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SolunarBloc>(
      create: (_) => SolunarBloc(
        getSolunar: GetSolunarUseCase(
          SolunarRepositoryImpl(
            remoteDataSource: SolunarRemoteDataSourceImpl(sl<Dio>()),
            networkInfo: sl<NetworkInfo>(),
          ),
        ),
      ),
      child: Theme(
        // Override theme to dark for this route only
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bgDark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.skyBlue,
            surface: AppColors.cardDark,
          ),
        ),
        child: const _SolunarView(),
      ),
    );
  }
}

class _SolunarView extends StatefulWidget {
  const _SolunarView();

  @override
  State<_SolunarView> createState() => _SolunarViewState();
}

class _SolunarViewState extends State<_SolunarView> {
  static const _bgDark = AppColors.midnightNavy;

  // Real per-day snapshots for the 10-day strip -- null entries are still
  // loading (or failed), rendered as a plain placeholder rather than a
  // fabricated phase/rating.
  List<SolunarSnapshot?> _calendarDays = List.filled(10, null);

  @override
  void initState() {
    super.initState();
    _requestData();
  }

  Future<void> _requestData() async {
    final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
    if (!mounted) return;
    context.read<SolunarBloc>().add(SolunarRequested(lat: lat, lon: lon));
    _loadCalendar(lat, lon);
  }

  Future<void> _loadCalendar(double lat, double lon) async {
    final getSolunar = context.read<SolunarBloc>().getSolunar;
    final today = DateTime.now();
    final results = await Future.wait(List.generate(10, (i) async {
      final result = await getSolunar(
          lat: lat, lon: lon, date: today.add(Duration(days: i)));
      return result.fold((_) => null, (snapshot) => snapshot);
    }));
    if (mounted) setState(() => _calendarDays = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Subtle star particles layer
          Positioned.fill(child: _StarField()),
          SafeArea(
            child: BlocBuilder<SolunarBloc, SolunarState>(
              builder: (context, state) {
                if (state is SolunarLoaded) {
                  return _LoadedContent(
                      snapshot: state.snapshot, calendarDays: _calendarDays);
                }
                if (state is SolunarError) {
                  return _ErrorView(
                      message: state.message, onRetry: _requestData);
                }
                return const _LoadingView();
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildHeader(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base, vertical: AppSpacing.md),
    child: Row(
      children: [
        GestureDetector(
          // Almanac tab (ShellRoute leaf, reached via context.go() from the
          // bottom nav, never pushed) -- nothing to pop back to, same fix
          // as pfz_map_page.dart/ocean_current_page.dart's own back buttons.
          onTap: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Text(
          AppLocalizations.of(context)!.solLunarTitle,
          style: AppTextStyles.h2(locale).copyWith(color: AppColors.fgOnDark),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────
// Loaded content — driven by SolunarSnapshot
// ─────────────────────────────────────────
class _LoadedContent extends StatelessWidget {
  final SolunarSnapshot snapshot;
  final List<SolunarSnapshot?> calendarDays;
  const _LoadedContent({required this.snapshot, required this.calendarDays});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(context)),
        // Moon hero
        SliverToBoxAdapter(child: _MoonHero(lunar: snapshot.lunar)),
        // Sun & Moon glass card
        SliverPadding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: _SunMoonCard(solar: snapshot.solar, lunar: snapshot.lunar),
          ),
        ),
        // Fishing windows
        SliverPadding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          sliver: SliverToBoxAdapter(
            child: _FishingWindowsCard(
              periods: snapshot.periods,
              activityScore: snapshot.activityScore,
            ),
          ),
        ),
        // 10-day moon calendar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
            child: _MoonCalendarStrip(days: calendarDays),
          ),
        ),
        // Activity gauge
        SliverPadding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: _ActivityGaugeCard(
              activityRating: snapshot.activityRating,
              activityScore: snapshot.activityScore,
              periods: snapshot.periods,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        const SliverToBoxAdapter(
          child: Attribution(color: AppColors.fgOnDark2),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl2)),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────
// Backend sends every timestamp in UTC (see sealanka-be's _utc_iso) -- .toLocal()
// is required here or every displayed time (sunrise, moonrise, period windows)
// renders several hours off from the device's actual local time.
String _fmtTime(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());

String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${m}m';
}

String _fmtRange(DateTime start, DateTime end) =>
    '${DateFormat('hh:mm').format(start.toLocal())} – ${DateFormat('hh:mm a').format(end.toLocal())}';

// ─────────────────────────────────────────
// Star field canvas
// ─────────────────────────────────────────
class _StarField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarFieldPainter());
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05);
    // 120 pseudo-random stars using index math
    for (int i = 0; i < 120; i++) {
      final x = (i * 173.0 + 47) % size.width;
      final y = (i * 97.0 + 31) % size.height;
      final r = (i % 3 == 0) ? 1.5 : 1.0;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────
// Moon hero
// ─────────────────────────────────────────
class _MoonHero extends StatelessWidget {
  final LunarData lunar;
  const _MoonHero({required this.lunar});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Column(
        children: [
          // Moon illustration — driven by illumination
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _CrescentMoonPainter(
                illumination: lunar.illuminationPercent / 100,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            '${DateFormat('EEEE').format(now)}, ${DateFormat('d MMM').format(now)}',
            style:
                AppTextStyles.bodyL(locale).copyWith(color: AppColors.fgOnDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${_phaseEmoji(lunar.phase)} ${lunar.phase}',
                  style: AppTextStyles.body(locale)
                      .copyWith(color: AppColors.fgOnDark2)),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  AppLocalizations.of(context)!.illuminationPercentLabel(
                      '${lunar.illuminationPercent.round()}'),
                  style: AppTextStyles.caption(locale)
                      .copyWith(color: AppColors.fgOnDark2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _phaseEmoji(String phase) {
  final p = phase.toLowerCase();
  if (p.contains('new')) return '🌑';
  if (p.contains('full')) return '🌕';
  if (p.contains('first quarter')) return '🌓';
  if (p.contains('last quarter') || p.contains('third quarter')) return '🌗';
  if (p.contains('waxing') && p.contains('crescent')) return '🌒';
  if (p.contains('waxing') && p.contains('gibbous')) return '🌔';
  if (p.contains('waning') && p.contains('gibbous')) return '🌖';
  if (p.contains('waning') && p.contains('crescent')) return '🌘';
  return '🌙';
}

class _CrescentMoonPainter extends CustomPainter {
  final double illumination; // 0.0–1.0
  const _CrescentMoonPainter({required this.illumination});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;

    // Glow halo
    final haloPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(cx, cy), r * 1.4, haloPaint);

    // Lit portion (silver disc)
    final moonPaint = Paint()
      ..color = const Color(0xFFD0D8E8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, moonPaint);

    // Shadow arc (dark circle offset to create crescent) — offset scales with
    // illumination so a fuller moon shows more lit surface.
    final shadowOffset = r * (1.2 - illumination.clamp(0.0, 1.0) * 1.2);
    final shadowPaint = Paint()
      ..color = AppColors.midnightNavy
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - shadowOffset, cy), r * 0.9, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _CrescentMoonPainter old) =>
      old.illumination != illumination;
}

// ─────────────────────────────────────────
// Sun & Moon glass card
// ─────────────────────────────────────────
class _SunMoonCard extends StatelessWidget {
  final SolarData solar;
  final LunarData lunar;
  const _SunMoonCard({required this.solar, required this.lunar});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.wb_sunny_rounded,
                      color: AppColors.coralGold, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(l10n.solarLabel,
                      style: AppTextStyles.caption(locale).copyWith(
                          color: AppColors.fgOnDark,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                _DataRow(
                    label: l10n.sunriseLabel, value: _fmtTime(solar.sunrise)),
                _DataRow(
                    label: l10n.solarNoonLabel,
                    value: _fmtTime(solar.solarNoon)),
                _DataRow(
                    label: l10n.sunsetLabel, value: _fmtTime(solar.sunset)),
                _DataRow(
                    label: l10n.daylightLabel,
                    value: _fmtDuration(solar.dayLength)),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 100,
            color: Colors.white.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.nightlight_round,
                      color: AppColors.info, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(l10n.lunarLabel,
                      style: AppTextStyles.caption(locale).copyWith(
                          color: AppColors.fgOnDark,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                _DataRow(
                    label: l10n.moonriseLabel, value: _fmtTime(lunar.moonrise)),
                _DataRow(label: l10n.phaseLabel, value: lunar.phase),
                _DataRow(
                    label: l10n.moonsetLabel, value: _fmtTime(lunar.moonset)),
                _DataRow(
                    label: l10n.illuminationLabel,
                    value: '${lunar.illuminationPercent.round()}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.caption(locale)
                  .copyWith(color: AppColors.fgOnDark2)),
          Text(value,
              style: AppTextStyles.caption(locale).copyWith(
                  color: AppColors.fgOnDark, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Fishing windows card
// ─────────────────────────────────────────
class _FishingWindowsCard extends StatelessWidget {
  final List<SolunarPeriod> periods;
  final int activityScore;
  const _FishingWindowsCard(
      {required this.periods, required this.activityScore});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.todaysFishingWindowsTitle,
                  style: AppTextStyles.bodyL(locale).copyWith(
                      color: AppColors.fgOnDark, fontWeight: FontWeight.w600)),
              _RatingStars(rating: (activityScore / 20).round().clamp(0, 5)),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          // 24h timeline bar
          _TimelineBar(periods: periods),
          const SizedBox(height: AppSpacing.base),
          ...periods.map((p) => _PeriodRow(period: p, now: now)),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final SolunarPeriod period;
  final DateTime now;
  const _PeriodRow({required this.period, required this.now});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final gold = period.isMajor ? AppColors.coralGold : AppColors.sand;
    final type = period.isMajor ? l10n.majorPeriodLabel : l10n.minorPeriodLabel;
    final passed = period.end.isBefore(now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('$type · ${_fmtRange(period.start, period.end)}',
                style: AppTextStyles.caption(locale).copyWith(
                    color: passed
                        ? AppColors.fgOnDark2.withOpacity(0.6)
                        : AppColors.fgOnDark)),
          ),
          if (!passed)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                  period.start.isAfter(now)
                      ? l10n.inDurationLabel(
                          _fmtDuration(period.start.difference(now)))
                      : l10n.activeLabel,
                  style: AppTextStyles.overline(locale).copyWith(
                      color: AppColors.success, fontWeight: FontWeight.w600)),
            )
          else
            Text(l10n.passedLabel,
                style: AppTextStyles.overline(locale)
                    .copyWith(color: AppColors.fgOnDark2.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  final List<SolunarPeriod> periods;
  const _TimelineBar({required this.periods});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(painter: _TimelineBarPainter(periods: periods)),
    );
  }
}

class _TimelineBarPainter extends CustomPainter {
  final List<SolunarPeriod> periods;
  const _TimelineBarPainter({required this.periods});

  @override
  void paint(Canvas canvas, Size size) {
    // Background bar
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 6, size.width, 8), const Radius.circular(4));
    canvas.drawRRect(rrect, bgPaint);

    // Period blocks — gold for major, sand for minor
    void drawBlock(double startH, double endH, Color color) {
      final x = (startH / 24) * size.width;
      final w = ((endH - startH) / 24).clamp(0.0, 24.0) * size.width;
      final blockPaint = Paint()..color = color;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 6, w, 8), const Radius.circular(2)),
          blockPaint);
    }

    // .toLocal() -- periods come in as UTC; without converting, the blocks
    // render several hours off from the "now" line (which is already local).
    double hourOf(DateTime dt) {
      final local = dt.toLocal();
      return local.hour + local.minute / 60.0;
    }

    for (final p in periods) {
      drawBlock(
        hourOf(p.start),
        hourOf(p.end),
        p.isMajor ? AppColors.coralGold : AppColors.sand.withOpacity(0.7),
      );
    }

    // Now indicator
    final now = DateTime.now();
    final nowX = (hourOf(now) / 24) * size.width;
    final nowPaint = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), nowPaint);
  }

  @override
  bool shouldRepaint(covariant _TimelineBarPainter old) =>
      old.periods != periods;
}

class _RatingStars extends StatelessWidget {
  final int rating;
  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          5,
          (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: AppColors.coralGold,
              )),
    );
  }
}

// ─────────────────────────────────────────
// 10-day moon calendar strip
// ─────────────────────────────────────────
class _MoonCalendarStrip extends StatelessWidget {
  final List<SolunarSnapshot?> days;
  const _MoonCalendarStrip({required this.days});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final weekdayLabels = [
      AppLocalizations.of(context)!.weekdayMon,
      AppLocalizations.of(context)!.weekdayTue,
      AppLocalizations.of(context)!.weekdayWed,
      AppLocalizations.of(context)!.weekdayThu,
      AppLocalizations.of(context)!.weekdayFri,
      AppLocalizations.of(context)!.weekdaySat,
      AppLocalizations.of(context)!.weekdaySun,
    ];
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final date = DateTime.now().add(Duration(days: i));
          final isToday = i == 0;
          final day = days[i];
          // Same 0-5 star scale as _FishingWindowsCard's rating, computed
          // from that day's real activity score -- not a fabricated guess.
          final rating =
              day == null ? 0 : (day.activityScore / 20).round().clamp(0, 5);
          return Container(
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isToday ? AppColors.coralGold : Colors.transparent,
                width: isToday ? 1.5 : 0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayLabels[date.weekday - 1],
                  style: AppTextStyles.overline(locale)
                      .copyWith(color: AppColors.fgOnDark2),
                ),
                Text('${date.day}',
                    style: AppTextStyles.bodyL(locale).copyWith(
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppColors.coralGold
                            : AppColors.fgOnDark)),
                Text(day == null ? '·' : _phaseEmoji(day.lunar.phase),
                    style: const TextStyle(fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      rating,
                      (_) => const Icon(Icons.circle,
                          size: 4, color: AppColors.coralGold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Activity gauge card
// ─────────────────────────────────────────
class _ActivityGaugeCard extends StatelessWidget {
  final String activityRating;
  final int activityScore;
  final List<SolunarPeriod> periods;
  const _ActivityGaugeCard(
      {required this.activityRating,
      required this.activityScore,
      required this.periods});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final score = (activityScore.clamp(0, 100)) / 100;
    final now = DateTime.now();
    final upcoming = periods.where((p) => p.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final next = upcoming.isNotEmpty ? upcoming.first : null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(l10n.fishingActivityTitle,
              style: AppTextStyles.bodyL(locale).copyWith(
                  color: AppColors.fgOnDark, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _GaugePainter(score: score),
              child: Align(
                alignment: const Alignment(0, 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(activityRating.toUpperCase(),
                        style: AppTextStyles.h2(locale).copyWith(
                            color: AppColors.coralGold,
                            fontWeight: FontWeight.w800)),
                    Text(
                        l10n.scoreOutOf100Label(
                            '${activityScore.clamp(0, 100)}'),
                        style: AppTextStyles.caption(locale)
                            .copyWith(color: AppColors.fgOnDark2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.success, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Text(
                    next != null
                        ? l10n.nextWindowStartsInLabel
                        : l10n.noMoreWindowsTodayLabel,
                    style: AppTextStyles.caption(locale)
                        .copyWith(color: AppColors.fgOnDark2)),
                if (next != null)
                  Text(_fmtDuration(next.start.difference(now)),
                      style: AppTextStyles.caption(locale).copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score; // 0.0–1.0
  const _GaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.92;
    // Capped by (cy - a top margin) as well as width -- previously derived
    // from width alone, which on any card wider than ~2.4x this box's
    // height pushed the arc's peak (at cy - radius) above y=0, drawing it
    // through the "Fishing activity" title in the sibling widget above.
    final radius = math.min(size.width * 0.42, cy - 14);

    // Track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        3.14, 3.14, false, trackPaint);

    // Score arc
    final scorePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.danger,
          AppColors.warning,
          AppColors.coralGold,
          AppColors.success
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        3.14, 3.14 * score, false, scorePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.score != score;
}

// ─────────────────────────────────────────
// Loading placeholder — dark themed
// ─────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  Widget _block({double? width, double height = 16, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
      children: [
        const SizedBox(height: AppSpacing.md),
        _block(width: 140, height: 24),
        const SizedBox(height: AppSpacing.xl),
        Center(child: _block(width: 120, height: 120, radius: 60)),
        const SizedBox(height: AppSpacing.base),
        Center(child: _block(width: 180, height: 16)),
        const SizedBox(height: AppSpacing.xs),
        Center(child: _block(width: 220, height: 14)),
        const SizedBox(height: AppSpacing.xl),
        _block(height: 140, radius: AppSpacing.radiusCard),
        const SizedBox(height: AppSpacing.base),
        _block(height: 200, radius: AppSpacing.radiusCard),
        const SizedBox(height: AppSpacing.base),
        _block(height: 120, radius: AppSpacing.radiusCard),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Error view with retry
// ─────────────────────────────────────────
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
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.fgOnDark2),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(locale)
                    .copyWith(color: AppColors.fgOnDark2)),
            const SizedBox(height: AppSpacing.base),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.fgOnDark, size: 18),
              label: Text(AppLocalizations.of(context)!.retry,
                  style: AppTextStyles.body(locale)
                      .copyWith(color: AppColors.fgOnDark)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.md),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
