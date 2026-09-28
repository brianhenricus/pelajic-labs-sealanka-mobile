import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sea_lanka/core/widgets/speed_tiers.dart';

/// Nullschool-style animated particle-flow overlay: hundreds of short-lived
/// particles advected through a cached (u, v) vector field grid, redrawn
/// every frame as fading trails. Must sit inside `FlutterMap.children`
/// (needs `MapCamera.of(context)` for lat/lon <-> screen projection, same
/// as every other layer in this app's map pages).
///
/// The server sends a raw grid snapshot (see sealanka-be's `/wind/grid` and
/// `/ocean/currents/grid`); this widget owns all interpolation, advection,
/// and rendering — the same division of labor as nullschool's own client
/// (cambecc/earth): server serves data, client animates it.
class ParticleFlowLayer extends StatefulWidget {
  /// Rows of [lat, lon, u_ms, v_ms].
  final List<List<double>> vectorPoints;
  final double gridStep;
  final double south, north, west, east;
  final int particleCount;

  /// Speed tiers to color particles by (kWindSpeedTiers / kCurrentSpeedTiers)
  /// — paired with [speedUnitConverter], which maps the field's native m/s
  /// to that tier list's display unit (identity for currents, *3.6 for
  /// wind's km/h tiers).
  final List<SpeedTier> speedTiers;
  final double Function(double metersPerSecond) speedUnitConverter;

  /// Ocean currents (~0.1-0.5 m/s) are physically much slower than wind
  /// (several m/s) -- the same visual-pace constant would make currents
  /// look almost static, so callers with slow-moving fields boost this
  /// (e.g. ~12x for ocean currents) to keep the animation equally legible.
  final double speedMultiplier;

  /// Number of sampled points kept per particle's trail (each sampled every
  /// [trailIntervalMs]). Higher = longer visible streaks.
  final int trailLength;
  final double trailIntervalMs;
  final double strokeWidth;

  const ParticleFlowLayer({
    super.key,
    required this.vectorPoints,
    required this.gridStep,
    required this.south,
    required this.north,
    required this.west,
    required this.east,
    required this.speedTiers,
    this.speedUnitConverter = _identity,
    this.particleCount = 250,
    this.speedMultiplier = 1.0,
    this.trailLength = 8,
    this.trailIntervalMs = 70.0,
    this.strokeWidth = 1.4,
  });

  static double _identity(double v) => v;

  @override
  State<ParticleFlowLayer> createState() => _ParticleFlowLayerState();
}

class _Particle {
  double lat, lon;
  double age;
  double msSinceTrailPoint;
  double lastSpeedMs = 0;
  final List<LatLng> trail = [];
  _Particle(this.lat, this.lon)
      : age = 0,
        msSinceTrailPoint = 0;
}

class _ParticleFlowLayerState extends State<ParticleFlowLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = math.Random();
  late List<_Particle> _particles;
  Map<String, (double, double)> _field = {};
  Duration _lastElapsed = Duration.zero;

  // Trail length + lifespan tuned for a legible, uncluttered flow rather
  // than a scientifically-meaningful window. Trail points are sampled
  // every trailIntervalMs (not every tick) so a short point count still
  // spans a real time window -- sampling every ~16ms tick instead left
  // trail history covering only ~0.1s, invisible against the total ~3s
  // lifetime's displacement (looked like static dots, not streaks).
  static const _maxAgeSeconds = 3.0;
  // Purely a visual pace, not real particle displacement speed -- real
  // wind (a few m/s) would be imperceptible at true scale over a few
  // seconds on a map spanning hundreds of km. Same artistic-acceleration
  // convention nullschool/Windy use; tune this one constant to speed up
  // or slow down the whole animation.
  static const _degreesPerMsPerUnitSpeed = 0.00006;

  @override
  void initState() {
    super.initState();
    _rebuildField();
    _particles = List.generate(widget.particleCount, (_) => _spawn());
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant ParticleFlowLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.vectorPoints, widget.vectorPoints)) {
      _rebuildField();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _rebuildField() {
    final field = <String, (double, double)>{};
    for (final p in widget.vectorPoints) {
      field[_key(p[0], p[1])] = (p[2], p[3]);
    }
    _field = field;
  }

  String _key(double lat, double lon) {
    final gLat = (lat / widget.gridStep).round();
    final gLon = (lon / widget.gridStep).round();
    return '$gLat:$gLon';
  }

  /// Bilinear sample of the 4 surrounding grid cells; null when none of
  /// them are cached (e.g. a masked/land cell or outside the bbox).
  (double, double)? _sample(double lat, double lon) {
    final step = widget.gridStep;
    final latFloor = (lat / step).floor() * step;
    final lonFloor = (lon / step).floor() * step;
    final tx = (lat - latFloor) / step;
    final ty = (lon - lonFloor) / step;

    final corners = [
      (latFloor, lonFloor, (1 - tx) * (1 - ty)),
      (latFloor + step, lonFloor, tx * (1 - ty)),
      (latFloor, lonFloor + step, (1 - tx) * ty),
      (latFloor + step, lonFloor + step, tx * ty),
    ];

    double u = 0, v = 0, weightSum = 0;
    for (final (cLat, cLon, weight) in corners) {
      final value = _field[_key(cLat, cLon)];
      if (value == null) continue;
      u += value.$1 * weight;
      v += value.$2 * weight;
      weightSum += weight;
    }
    if (weightSum == 0) return null;
    return (u / weightSum, v / weightSum);
  }

  _Particle _spawn() {
    final lat =
        widget.south + _rng.nextDouble() * (widget.north - widget.south);
    final lon = widget.west + _rng.nextDouble() * (widget.east - widget.west);
    return _Particle(lat, lon)..age = _rng.nextDouble() * _maxAgeSeconds;
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dtMs = (elapsed - _lastElapsed).inMilliseconds.toDouble();
    _lastElapsed = elapsed;
    if (_field.isEmpty || dtMs <= 0) return;

    for (final particle in _particles) {
      final sample = _sample(particle.lat, particle.lon);
      if (sample != null) {
        final (u, v) = sample;
        particle.lastSpeedMs = math.sqrt(u * u + v * v);
        final scale = _degreesPerMsPerUnitSpeed * dtMs * widget.speedMultiplier;
        final latRad = particle.lat * math.pi / 180;
        particle.lon += u * scale / math.cos(latRad);
        particle.lat += v * scale;
        particle.age += dtMs / 1000;
        particle.msSinceTrailPoint += dtMs;
        if (particle.msSinceTrailPoint >= widget.trailIntervalMs) {
          particle.msSinceTrailPoint = 0;
          particle.trail.add(LatLng(particle.lat, particle.lon));
          if (particle.trail.length > widget.trailLength) {
            particle.trail.removeAt(0);
          }
        }
      }

      final outOfBounds = particle.lat < widget.south ||
          particle.lat > widget.north ||
          particle.lon < widget.west ||
          particle.lon > widget.east;
      if (sample == null || particle.age > _maxAgeSeconds || outOfBounds) {
        final fresh = _spawn();
        particle.lat = fresh.lat;
        particle.lon = fresh.lon;
        particle.age = 0;
        particle.msSinceTrailPoint = 0;
        particle.trail.clear();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ParticlePainter(
          particles: _particles,
          camera: camera,
          speedTiers: widget.speedTiers,
          speedUnitConverter: widget.speedUnitConverter,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final MapCamera camera;
  final List<SpeedTier> speedTiers;
  final double Function(double) speedUnitConverter;
  final double strokeWidth;

  _ParticlePainter({
    required this.particles,
    required this.camera,
    required this.speedTiers,
    required this.speedUnitConverter,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final particle in particles) {
      if (particle.trail.length < 2) continue;
      final color =
          colorForSpeed(speedTiers, speedUnitConverter(particle.lastSpeedMs));
      for (var i = 1; i < particle.trail.length; i++) {
        final p1 = camera.latLngToScreenPoint(particle.trail[i - 1]);
        final p2 = camera.latLngToScreenPoint(particle.trail[i]);
        final opacity = i / particle.trail.length;
        paint.color = color.withOpacity(opacity * 0.85);
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
