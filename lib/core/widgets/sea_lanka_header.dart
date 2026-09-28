import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';

/// The Sea Lanka gradient hero header: navy gradient + subtle wave overlay +
/// title/subtitle and optional leading / trailing / location / status slots.
/// Maps to the React `AppHeader` component (`components-appheader.html`).
///
/// Place at the top of a screen's scroll view or column.
class SeaLankaHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;

  /// Optional pill row rendered under the title (e.g. location + status badge).
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  const SeaLankaHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppSpacing.radiusXl),
      ),
      child: CustomPaint(
        painter: _WavePainter(),
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.h1(locale)
                                  .copyWith(color: AppColors.fgOnDark),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: AppTextStyles.body(locale)
                                    .copyWith(color: AppColors.fgOnDark2),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (actions != null) ...actions!,
                    ],
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle wave line, ~8% white, echoing the DS header overlay.
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final h = size.height;
    final w = size.width;
    for (var k = 0; k < 2; k++) {
      final y = h * (0.55 + k * 0.18);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= w; x += w / 4) {
        path.relativeQuadraticBezierTo(w / 8, -10, w / 4, 0);
        path.relativeQuadraticBezierTo(w / 8, 10, w / 4, 0);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small translucent location pill for the header footer.
class HeaderLocationPill extends StatelessWidget {
  final String location;
  const HeaderLocationPill({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_outlined,
              size: 14, color: AppColors.fgOnDark2),
          const SizedBox(width: 4),
          Text(location,
              style: AppTextStyles.caption(locale)
                  .copyWith(color: AppColors.fgOnDark)),
        ],
      ),
    );
  }
}
