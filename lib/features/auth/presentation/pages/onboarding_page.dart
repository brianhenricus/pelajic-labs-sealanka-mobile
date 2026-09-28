import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/constants/sri_lanka_geo.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/speed_tiers.dart';

/// Splash → 3-screen onboarding flow (PFZ · Wind · Languages),
/// ported faithfully from sea-lanka-design-system/project/screens/onboarding.html
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  List<_OnbData> _pages(AppLocalizations t) => [
        _OnbData(
          headline: t.onboardingHeadline1,
          description: t.onboardingDescription1,
          cta: t.onboardingNext,
        ),
        _OnbData(
          headline: t.onboardingHeadline2,
          description: t.onboardingDescription2,
          cta: t.onboardingNext,
        ),
        _OnbData(
          headline: t.onboardingHeadline3,
          description: t.onboardingDescription3,
          cta: t.onboardingGetStarted,
        ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      sl<Box>().put('onboarding_seen', true);
    } catch (_) {}
    if (mounted) context.go(AppRoutes.login);
  }

  static const _pageCount = 3;

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final pages = _pages(t);
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _OnboardingScreen(
              index: i,
              data: pages[i],
              page: _page,
              total: pages.length,
              onNext: _next,
            ),
          ),
          // Skip button (top-right, white over the dark hero)
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            right: AppSpacing.base,
            child: Builder(
              builder: (context) {
                final locale = Localizations.localeOf(context);
                return TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  ),
                  child: Text(
                    t.onboardingSkip,
                    style: AppTextStyles.body(locale).copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OnbData {
  final String headline;
  final String description;
  final String cta;
  const _OnbData(
      {required this.headline, required this.description, required this.cta});
}

class _OnboardingScreen extends StatelessWidget {
  final int index;
  final _OnbData data;
  final int page;
  final int total;
  final VoidCallback onNext;

  const _OnboardingScreen({
    required this.index,
    required this.data,
    required this.page,
    required this.total,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      children: [
        // Hero — 62% height, navy gradient with illustration + bottom wave
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.midnightNavy, AppColors.deepSeaBlue],
                    ),
                  ),
                  child: switch (index) {
                    0 => const _PfzHero(),
                    1 => const _WindHero(),
                    _ => const _LanguageHero(),
                  },
                ),
              ),
              // Bottom wave transition into the light content area
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: 50,
                child: CustomPaint(
                  painter: _BottomWavePainter(AppColors.backgroundLight),
                ),
              ),
            ],
          ),
        ),
        // Content — headline, description, footer (dots + CTA)
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl2, AppSpacing.xl, AppSpacing.xl2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.headline,
                  style: AppTextStyles.display(locale)
                      .copyWith(color: AppColors.fg1),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    data.description,
                    style: AppTextStyles.bodyL(locale)
                        .copyWith(color: AppColors.fg2),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Dots(active: page, total: total),
                    SeaLankaButton(
                      label: data.cta,
                      variant: SeaLankaButtonVariant.cta,
                      fullWidth: false,
                      icon: Icons.arrow_forward_rounded,
                      trailingIcon: true,
                      onPressed: onNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Footer pieces
// ─────────────────────────────────────────────────────────
class _Dots extends StatelessWidget {
  final int active;
  final int total;
  const _Dots({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.marineBlue : AppColors.borderLight,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Hero 1 — PFZ zones illustration
// ─────────────────────────────────────────────────────────
class _PfzHero extends StatelessWidget {
  const _PfzHero();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return Stack(
          children: [
            // Grid
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
            // Zone blobs (radial gradient, blurred)
            _zoneBlob(
              left: w * 0.20,
              top: h * 0.30,
              bw: 150,
              bh: 110,
              colors: const [
                Color(0xFFF4C430),
                Color(0x99F4A030),
                Color(0x00F4A030)
              ],
            ),
            _zoneBlob(
              left: w * 0.56,
              top: h * 0.58,
              bw: 110,
              bh: 80,
              colors: const [
                Color(0xFFF08A2A),
                Color(0x80E85D1A),
                Color(0x00E85D1A)
              ],
            ),
            _zoneBlob(
              left: w * 0.12,
              top: h * 0.66,
              bw: 90,
              bh: 70,
              colors: const [
                Color(0xFFE63946),
                Color(0x80B22234),
                Color(0x00B22234)
              ],
            ),
            // Pins
            Positioned(
              left: w * 0.34,
              top: h * 0.34,
              child: const _ZonePin(
                  value: '92',
                  fill: Color(0xFFF4C430),
                  fg: AppColors.midnightNavy),
            ),
            Positioned(
              left: w * 0.62,
              top: h * 0.60,
              child: const _ZonePin(
                  value: '68', fill: Color(0xFFE85D1A), fg: Colors.white),
            ),
            // Fish/logo mark, right side — matches .pfz-fish in the source design
            Positioned(
              right: 18,
              top: h * 0.30,
              child: Transform.rotate(
                angle: -8 * math.pi / 180,
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo/logo-sealanka-transparent.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _zoneBlob({
    required double left,
    required double top,
    required double bw,
    required double bh,
    required List<Color> colors,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: bw,
        height: bh,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            stops: const [0.0, 0.5, 0.75],
          ),
        ),
      ),
    );
  }
}

class _ZonePin extends StatelessWidget {
  final String value;
  final Color fill;
  final Color fg;
  const _ZonePin({required this.value, required this.fill, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: fill.withOpacity(0.3), blurRadius: 0, spreadRadius: 6),
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.skyBlue.withOpacity(0.6)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────
// Hero 2 — Wind field (earth.nullschool-style streamlines)
// ─────────────────────────────────────────────────────────
/// Same visual language as the real wind map (wind_map_page.dart):
/// darkened basemap, animated flow lines colored by [kWindSpeedTiers], and a
/// matching speed legend — this is a decorative procedural field (no live
/// data), so only the look is ported, not the particle system itself.
class _WindHero extends StatefulWidget {
  const _WindHero();

  @override
  State<_WindHero> createState() => _WindHeroState();
}

class _WindHeroState extends State<_WindHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Darkened basemap, matching the real map's OSM-tiles-under-a-
        // black-overlay treatment (see wind_map_page.dart) instead of a
        // plain navy gradient.
        Positioned.fill(
          child: Container(color: Colors.black.withOpacity(0.2)),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) =>
                CustomPaint(painter: _WindFieldPainter(_ctrl.value)),
          ),
        ),
        // Wind scale (bottom, matches SpeedLegend's tiers/labels)
        Positioned(
          left: 18,
          right: 18,
          bottom: 56,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.midnightNavy.withOpacity(0.72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tier in kWindSpeedTiers)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: tier.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tier.label,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB8C7E0),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ports the JS vector-field + streamline integrator from onboarding.html,
/// recolored to [kWindSpeedTiers] and animated with moving particles along
/// each flow line (via PathMetrics) so it reads as the same kind of
/// particle-flow animation as the real wind map's [ParticleFlowLayer],
/// instead of a static gradient drawing.
class _WindFieldPainter extends CustomPainter {
  final double progress; // 0..1, looping

  _WindFieldPainter(this.progress);
  static const double _vbW = 400, _vbH = 240;

  // Deterministic PRNG matching the JS (seed 1337)
  int _seed = 1337;
  double _rnd() {
    _seed = (_seed * 9301 + 49297) % 233280;
    return _seed / 233280;
  }

  static const double _baseAng = 38 * math.pi / 180;
  static final double _baseDx = math.cos(_baseAng);
  static final double _baseDy = -math.sin(_baseAng);

  List<double> _field(double x, double y) {
    double dx = _baseDx, dy = _baseDy;
    // Vortex 1 (anti-clockwise) east of Sri Lanka
    {
      const cx = 300.0, cy = 165.0;
      final px = x - cx, py = y - cy;
      final r = math.sqrt(px * px + py * py) + 0.001;
      final fall = 1 / (1 + math.pow(r / 50, 2));
      final s = 1.6 * fall;
      dx += -py / r * s;
      dy += px / r * s;
    }
    // Vortex 2 (clockwise) NW over India
    {
      const cx = 70.0, cy = 50.0;
      final px = x - cx, py = y - cy;
      final r = math.sqrt(px * px + py * py) + 0.001;
      final fall = 1 / (1 + math.pow(r / 60, 2));
      final s = 1.1 * fall;
      dx += py / r * s;
      dy += -px / r * s;
    }
    // Flow around Sri Lanka — outward push
    {
      const cx = 200.0, cy = 120.0;
      final px = x - cx, py = y - cy;
      final r = math.sqrt(px * px + py * py) + 0.001;
      if (r < 92) {
        final push = (92 - r) / 92 * 0.6;
        dx += px / r * push;
        dy += py / r * push;
      }
    }
    return [dx, dy];
  }

  double _mag(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

  ({List<Offset> pts, double avg}) _streamline(
      double x0, double y0, int steps, double dt) {
    final pts = <Offset>[Offset(x0, y0)];
    double sum = 0;
    int n = 0;
    double x = x0, y = y0;
    for (int i = 0; i < steps; i++) {
      final f = _field(x, y);
      final m = _mag(f[0], f[1]);
      if (m < 0.01) break;
      sum += m;
      n++;
      x += f[0] / m * dt;
      y += f[1] / m * dt;
      if (x < -10 || x > _vbW + 10 || y < -10 || y > _vbH + 10) break;
      pts.add(Offset(x, y));
    }
    x = x0;
    y = y0;
    for (int i = 0; i < (steps * 0.45).floor(); i++) {
      final f = _field(x, y);
      final m = _mag(f[0], f[1]);
      if (m < 0.01) break;
      sum += m;
      n++;
      x -= f[0] / m * dt;
      y -= f[1] / m * dt;
      if (x < -10 || x > _vbW + 10 || y < -10 || y > _vbH + 10) break;
      pts.insert(0, Offset(x, y));
    }
    return (pts: pts, avg: n > 0 ? sum / n : 0);
  }

  // Same 5 bands/colors as kWindSpeedTiers (calm/light/moderate/strong/storm)
  // so this decorative field reads as the same wind map, not a lookalike
  // palette.
  static final _ramp = [
    (max: 0.55, color: kWindSpeedTiers[0].color, op: 0.4, sw: 0.7),
    (max: 0.95, color: kWindSpeedTiers[1].color, op: 0.5, sw: 0.7),
    (max: 1.35, color: kWindSpeedTiers[2].color, op: 0.6, sw: 0.8),
    (max: 1.85, color: kWindSpeedTiers[3].color, op: 0.75, sw: 0.9),
    (max: 99.0, color: kWindSpeedTiers[4].color, op: 0.85, sw: 1.0),
  ];

  int _bandFor(double speed) {
    for (int i = 0; i < _ramp.length; i++) {
      if (speed < _ramp[i].max) return i;
    }
    return _ramp.length - 1;
  }

  // Streamline integration (a PRNG walk over 160 seeds) is too expensive to
  // redo every animation frame -- a new [_WindFieldPainter] is built each
  // frame by AnimatedBuilder, so this cache lives on the class (static) and
  // is keyed by canvas size, computed once and reused for every subsequent
  // frame at that size. Only the moving particle dashes below actually
  // change per frame.
  static Size? _cachedSize;
  static List<Path>? _cachedBandPaths;

  List<Path> _bandPathsFor(Size size) {
    if (_cachedSize == size && _cachedBandPaths != null) {
      return _cachedBandPaths!;
    }
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;
    final bandPaths = List.generate(_ramp.length, (_) => Path());
    const n = 160;
    for (int i = 0; i < n; i++) {
      final seedX = -10 + _rnd() * (_vbW + 20);
      final seedY = -10 + _rnd() * (_vbH + 20);
      final sl = _streamline(seedX, seedY, 26 + (_rnd() * 14).floor(), 2.4);
      if (sl.pts.length < 4) continue;
      final p = bandPaths[_bandFor(sl.avg)];
      p.moveTo(sl.pts[0].dx * sx, sl.pts[0].dy * sy);
      for (int k = 1; k < sl.pts.length; k++) {
        p.lineTo(sl.pts[k].dx * sx, sl.pts[k].dy * sy);
      }
    }
    _cachedSize = size;
    _cachedBandPaths = bandPaths;
    return bandPaths;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vbW;
    final sy = size.height / _vbH;

    // lat/long grid
    final gridPaint = Paint()
      ..color = const Color(0xFF78B4C8).withOpacity(0.08)
      ..strokeWidth = 0.5;
    for (double gy = 40; gy < _vbH; gy += 40) {
      canvas.drawLine(
          Offset(0, gy * sy), Offset(size.width, gy * sy), gridPaint);
    }
    for (double gx = 80; gx < _vbW; gx += 80) {
      canvas.drawLine(
          Offset(gx * sx, 0), Offset(gx * sx, size.height), gridPaint);
    }

    final bandPaths = _bandPathsFor(size);

    for (int i = 0; i < _ramp.length; i++) {
      final band = _ramp[i];
      // Faint base line -- the flow lines themselves, dim so the moving
      // particles below read as the clearest layer (same relationship as
      // the real map's particle trails over a mostly-static basemap).
      final basePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = band.color.withOpacity(band.op * 0.35)
        ..strokeWidth = band.sw * ((sx + sy) / 2);
      canvas.drawPath(bandPaths[i], basePaint);

      // Moving particle dash sliding along each flow line -- mirrors
      // ParticleFlowLayer's animated trails on the real wind map.
      final particlePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = band.color.withOpacity(band.op)
        ..strokeWidth = band.sw * ((sx + sy) / 2) * 1.4;

      for (final metric in bandPaths[i].computeMetrics()) {
        final length = metric.length;
        if (length < 8) continue;
        const dashLen = 14.0;
        // Stagger each path's phase off the metric's own length so
        // particles don't all move in lockstep.
        final offset = (progress * length * 1.6 + length * 0.37) % length;
        final start = offset;
        final end = (offset + dashLen).clamp(0.0, length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), particlePaint);
        }
      }
    }

    // Real Sri Lanka coastline (see sri_lanka_geo.dart, a real GeoJSON
    // boundary, not a hand-drawn approximation) -- target box uses this
    // data's own ~1.69:1 (height:width) bounding-box aspect ratio, so it's
    // never stretched, centered on the "flow around Sri Lanka" vortex in
    // _field() above, scaled by sx/sy like everything else here.
    final landFill = Paint()..color = const Color(0xFF08162E).withOpacity(0.6);
    final landStroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFDCF0FF).withOpacity(0.6)
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round;

    final land = buildSriLankaLandPath(
      Rect.fromLTWH(146.85 * sx, 30 * sy, 106.3 * sx, 180 * sy),
    );
    canvas.drawPath(land, landFill);
    canvas.drawPath(land, landStroke);
  }

  @override
  bool shouldRepaint(covariant _WindFieldPainter old) =>
      old.progress != progress;
}

// ─────────────────────────────────────────────────────────
// Hero 3 — Language badges with ripple
// ─────────────────────────────────────────────────────────
class _LanguageHero extends StatefulWidget {
  const _LanguageHero();

  @override
  State<_LanguageHero> createState() => _LanguageHeroState();
}

class _LanguageHeroState extends State<_LanguageHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LangBadge(
              glyph: 'Aa',
              label: 'English',
              fontFamily: 'Inter',
              phase: 0.0,
              controller: _ctrl),
          const SizedBox(width: 16),
          _LangBadge(
              glyph: 'අ',
              label: 'සිංහල',
              fontFamily: 'NotoSansSinhala',
              phase: 0.166,
              controller: _ctrl),
          const SizedBox(width: 16),
          _LangBadge(
              glyph: 'த',
              label: 'தமிழ்',
              fontFamily: 'NotoSansTamil',
              phase: 0.333,
              controller: _ctrl),
        ],
      ),
    );
  }
}

class _LangBadge extends StatelessWidget {
  final String glyph;
  final String label;
  final String fontFamily;
  final double phase; // 0..1 ripple offset
  final AnimationController controller;

  const _LangBadge({
    required this.glyph,
    required this.label,
    required this.fontFamily,
    required this.phase,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 114,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Ripple rings
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              double t = (controller.value + phase) % 1.0;
              return CustomPaint(
                size: const Size(92, 92),
                painter: _RipplePainter(t),
              );
            },
          ),
          // Badge core
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.skyBlue.withOpacity(0.4), width: 1.5),
            ),
            child: Text(
              glyph,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          // Label
          Positioned(
            bottom: 0,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB8C7E0),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double t; // 0..1
  _RipplePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2 + 10;
    // scale 0.92 → 1.5, opacity 0.6 → 0
    final scale = 0.92 + (1.5 - 0.92) * t;
    final opacity = (0.6 * (1 - t)).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.skyBlue.withOpacity(opacity);
    canvas.drawCircle(center, baseR * scale, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────
// Shared bottom wave (hero → light content transition)
// ─────────────────────────────────────────────────────────
class _BottomWavePainter extends CustomPainter {
  final Color color;
  _BottomWavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, h * (40 / 60))
      ..cubicTo(w * 0.25, h * (20 / 60), w * 0.5, h * (55 / 60), w * 0.75,
          h * (30 / 60))
      ..cubicTo(
          w * 0.875, h * (15 / 60), w * 0.95, h * (40 / 60), w, h * (30 / 60))
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
