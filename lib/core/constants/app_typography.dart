import 'package:flutter/material.dart';

/// Sea Lanka typography — mirrors `colors_and_type.css` exactly.
///
/// The design system defines 8 semantic roles (Display, H1, H2, H3, BodyL,
/// Body, Caption, Overline). These do not map cleanly onto Material's 15
/// `TextTheme` slots, so [AppTextStyles] exposes the DS roles as locale-aware
/// getters and is the canonical API for app code. A minimal Material
/// [TextTheme] is still built (see [buildTextTheme]) so framework widgets
/// inherit sane defaults.
///
/// Fonts (per DS): display/UI = Inter; body = Noto Sans (Inter is the DS body
/// fallback and the only real TTF currently shipped, so it is used for body
/// too until Noto Sans files are added). Sinhala/Tamil use their Noto variants.
class AppTypography {
  AppTypography._();

  /// Display / UI family. `--sl-font-display: "Inter", ...`
  static String displayFont(Locale locale) {
    switch (locale.languageCode) {
      case 'si':
        return 'NotoSansSinhala';
      case 'ta':
        return 'NotoSansTamil';
      default:
        return 'Inter';
    }
  }

  /// Body family. `--sl-font-body: "Noto Sans", "Inter", ...`
  /// Inter is used for `en` until a real Noto Sans TTF is supplied.
  static String bodyFont(Locale locale) {
    switch (locale.languageCode) {
      case 'si':
        return 'NotoSansSinhala';
      case 'ta':
        return 'NotoSansTamil';
      default:
        return 'Inter';
    }
  }

  /// Sinhala needs +15% line-height (`--sl-lh-mult-sinhala`).
  static double _lineHeightMultiplier(Locale locale) =>
      locale.languageCode == 'si' ? 1.15 : 1.0;

  /// Tamil runs ~10% wider; add 0.01em letter-spacing (`:lang(ta)` rule).
  static double _extraLetterSpacingEm(Locale locale) =>
      locale.languageCode == 'ta' ? 0.01 : 0.0;

  /// Builds a Material [TextTheme] mapped from the DS roles, so framework
  /// widgets (default `Text`, dialogs, inputs) render with DS metrics.
  static TextTheme buildTextTheme(Locale locale) {
    return TextTheme(
      displayLarge: AppTextStyles.display(locale),
      displayMedium: AppTextStyles.display(locale),
      displaySmall: AppTextStyles.h1(locale),
      headlineLarge: AppTextStyles.h1(locale),
      headlineMedium: AppTextStyles.h2(locale),
      headlineSmall: AppTextStyles.h3(locale),
      titleLarge: AppTextStyles.h2(locale),
      titleMedium: AppTextStyles.h3(locale),
      titleSmall: AppTextStyles.bodyL(locale),
      bodyLarge: AppTextStyles.bodyL(locale),
      bodyMedium: AppTextStyles.body(locale),
      bodySmall: AppTextStyles.caption(locale),
      labelLarge:
          AppTextStyles.body(locale).copyWith(fontWeight: FontWeight.w600),
      labelMedium: AppTextStyles.caption(locale),
      labelSmall: AppTextStyles.overline(locale),
    );
  }
}

/// Canonical Sea Lanka text styles. One method per DS role.
/// Pass the active [Locale] so script-specific font + metric modifiers apply.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _style(
    Locale locale, {
    required double size,
    required double lineHeightPx,
    required FontWeight weight,
    double letterSpacingEm = 0.0,
    bool body = false,
  }) {
    final family =
        body ? AppTypography.bodyFont(locale) : AppTypography.displayFont(locale);
    final height =
        (lineHeightPx / size) * AppTypography._lineHeightMultiplier(locale);
    final letterSpacing =
        (letterSpacingEm + AppTypography._extraLetterSpacingEm(locale)) * size;
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }

  // — Display family (Inter) —
  static TextStyle display(Locale locale) => _style(locale,
      size: 28, lineHeightPx: 34, weight: FontWeight.w700, letterSpacingEm: -0.01);

  static TextStyle h1(Locale locale) => _style(locale,
      size: 24, lineHeightPx: 30, weight: FontWeight.w700, letterSpacingEm: -0.01);

  static TextStyle h2(Locale locale) =>
      _style(locale, size: 20, lineHeightPx: 26, weight: FontWeight.w600);

  static TextStyle h3(Locale locale) =>
      _style(locale, size: 18, lineHeightPx: 24, weight: FontWeight.w600);

  // — Body family (Noto Sans / Inter) —
  static TextStyle bodyL(Locale locale) => _style(locale,
      size: 16, lineHeightPx: 24, weight: FontWeight.w400, body: true);

  static TextStyle body(Locale locale) => _style(locale,
      size: 14, lineHeightPx: 20, weight: FontWeight.w400, body: true);

  static TextStyle caption(Locale locale) => _style(locale,
      size: 12, lineHeightPx: 16, weight: FontWeight.w500, body: true);

  /// Overline — render the text in UPPERCASE at the call site (Flutter has no
  /// `text-transform`). 0.08em tracking, tertiary colour by convention.
  static TextStyle overline(Locale locale) => _style(locale,
      size: 11,
      lineHeightPx: 14,
      weight: FontWeight.w600,
      letterSpacingEm: 0.08,
      body: true);
}
