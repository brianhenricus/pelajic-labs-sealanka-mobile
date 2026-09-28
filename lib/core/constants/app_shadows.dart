import 'package:flutter/material.dart';

/// Shadow tokens — mirrors the SHADOW block of `colors_and_type.css`.
class AppShadows {
  AppShadows._();

  /// `--sl-shadow-card: 0 2px 8px rgba(10, 31, 68, 0.08)`
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x140A1F44), // 8% of #0A1F44
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// `--sl-shadow-fab: 0 8px 20px rgba(91, 168, 232, 0.45)` — sky-blue glow.
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x735BA8E8), // 45% of #5BA8E8
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// `--sl-shadow-sheet: 0 -4px 24px rgba(10, 31, 68, 0.12)` — lift.
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x1F0A1F44), // 12% of #0A1F44
      blurRadius: 24,
      offset: Offset(0, -4),
    ),
  ];
}
