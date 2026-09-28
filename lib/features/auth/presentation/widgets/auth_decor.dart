import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/main.dart' show appLocale;

/// Navy gradient hero backdrop with layered marine ripple waves, shared by the
/// auth screens. Ports the `.bg` + `.waves` layers from login.html / auth-flow.html.
class _AuthWavesPainter extends CustomPainter {
  const _AuthWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Three stacked marine-blue ripples at 6/5/4% opacity, anchored to the
    // bottom 35% of the screen.
    const top = 0.65; // start the wave band ~65% down
    final bands = <(double offset, double opacity)>[
      (0.00, 0.06),
      (0.05, 0.05),
      (0.10, 0.04),
    ];
    for (final band in bands) {
      final paint = Paint()
        ..color = AppColors.marineBlue.withOpacity(band.$2)
        ..style = PaintingStyle.fill;
      final y = h * (top + band.$1);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(w * 0.20, y - h * 0.06, w * 0.42, y + h * 0.05, w * 0.62,
            y - h * 0.02)
        ..cubicTo(
            w * 0.80, y - h * 0.07, w * 0.92, y + h * 0.01, w, y - h * 0.03)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: const CustomPaint(painter: _AuthWavesPainter()),
    );
  }
}

/// Public wrapper — full-bleed navy gradient + ripple waves for auth screens.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) => const _AuthBackdrop();
}

/// Real Sea Lanka logo mark used in the auth hero. Matches `.logo-halo img`
/// in login.html — the actual fish-and-wave artwork, not a placeholder icon.
class AuthLogoMark extends StatelessWidget {
  final double size;
  const AuthLogoMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo/logo-sealanka-transparent.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// "Sea Lanka" wordmark + tagline for the auth hero.
class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      children: [
        Text(
          AppLocalizations.of(context)!.appName,
          style: AppTextStyles.display(locale).copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppLocalizations.of(context)!.appTagline,
          style: AppTextStyles.body(locale).copyWith(color: AppColors.skyBlue),
        ),
      ],
    );
  }
}

/// Language toggle pills (EN / සි / த) shown under the auth hero tagline —
/// switches the app-wide locale directly. Matches `.lang-pill` in
/// login.html / signup.html.
class AuthLangPillRow extends StatelessWidget {
  const AuthLangPillRow({super.key});

  static const _langs = [
    ('en', '🇬🇧 EN'),
    ('si', '🇱🇰 සි'),
    ('ta', '🇱🇰 த'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _langs.map((lang) {
            final isActive = lang.$1 == locale.languageCode;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => appLocale.value = Locale(lang.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.white
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    lang.$2,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? AppColors.deepSeaBlue
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
