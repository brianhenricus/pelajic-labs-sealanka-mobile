/// Spacing, radii, and component sizes — mirrors the SPACING block of
/// `colors_and_type.css`. Strict 4dp grid.
class AppSpacing {
  AppSpacing._();

  // — 4dp scale (--sl-s-*) —
  static const double s0 = 0.0;
  static const double xs = 4.0; // s1
  static const double sm = 8.0; // s2
  static const double md = 12.0; // s3
  static const double base = 16.0; // s4 — screen padding
  static const double lg = 20.0; // s5
  static const double xl = 24.0; // s6
  static const double xl2 = 32.0; // s8
  static const double xl3 = 40.0; // s10
  static const double xl4 = 48.0; // s12
  static const double xl5 = 64.0; // s16

  // — Radii (--sl-r-*) —
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0; // button / input
  static const double radiusLg = 16.0; // card
  static const double radiusXl = 24.0; // bottom sheet top
  static const double radiusFull = 999.0; // pill / chip
  static const double radiusButton = 12.0;
  static const double radiusInput = 12.0;
  static const double radiusCard = 16.0;
  static const double radiusSheet = 24.0;

  // — Component heights (--sl-h-*) —
  static const double buttonHeight = 48.0;
  static const double fabSize = 56.0;
  static const double bottomNavHeight = 80.0;
  static const double tapMin = 44.0;

  // — App-specific —
  static const double cardPadding = 16.0;
  static const double pagePadding = 16.0; // --sl-s-4
  static const double appBarHeight = 60.0;
}
