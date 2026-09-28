import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';

/// Small circular compass overlay (top-left on the wind map mockup) — N/S
/// stay fixed (the dial doesn't rotate); only the gold needle moves, angled
/// by the wind's true bearing relative to the phone's own live heading (from
/// the magnetometer), so turning the phone alone visibly swings the needle.
class CompassRose extends StatelessWidget {
  final double directionDeg;

  /// Device's own compass heading in degrees (0 = phone facing true north),
  /// or null while unavailable (no magnetometer, or a stream error) -- the
  /// needle just shows the raw bearing in that case rather than a fake offset.
  final double? headingDeg;

  const CompassRose({super.key, required this.directionDeg, this.headingDeg});

  @override
  Widget build(BuildContext context) {
    final heading = headingDeg ?? 0.0;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 6,
            child: Text('N',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          const Positioned(
            bottom: 6,
            child: Text('S',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          CompassNeedle(directionDeg: directionDeg - heading, size: 26),
        ],
      ),
    );
  }
}

/// Custom-painted needle, straight up (north) at 0° rotation -- unlike
/// Icons.navigation*, whose glyph is not actually centered on true north,
/// which made the wind-map compass visibly disagree with its own N/S-from
/// compass-point label (e.g. showing "S" while the icon pointed east).
class CompassNeedle extends StatelessWidget {
  final double directionDeg;
  final double size;
  final Color color;
  const CompassNeedle({
    super.key,
    required this.directionDeg,
    this.size = 26,
    this.color = AppColors.coralGold,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: directionDeg * 3.1415926535 / 180,
      child: CustomPaint(
        size: Size(size, size),
        painter: _NeedlePainter(color: color),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final Color color;
  _NeedlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width * 0.8, size.height)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(size.width * 0.2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) =>
      oldDelegate.color != color;
}
