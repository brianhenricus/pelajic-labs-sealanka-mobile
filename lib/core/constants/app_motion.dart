import 'package:flutter/animation.dart';

/// Motion tokens — mirrors the MOTION block of `colors_and_type.css`.
/// No spinners anywhere — use shimmer skeletons (see LoadingShimmer).
class AppMotion {
  AppMotion._();

  /// Page transitions (slide, never horizontal tabs).
  static const Duration page = Duration(milliseconds: 250);

  /// Tap response — scale to 0.98.
  static const Duration tap = Duration(milliseconds: 100);
  static const double tapScale = 0.98;

  /// Live-data pulse — gentle opacity pulse on the green dot only.
  static const Duration pulse = Duration(milliseconds: 1500);

  /// `--sl-ease-out: cubic-bezier(.22, .61, .36, 1)`
  static const Cubic easeOut = Cubic(0.22, 0.61, 0.36, 1.0);
}
