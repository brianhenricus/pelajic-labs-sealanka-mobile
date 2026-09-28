import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';

/// Default surface card: 16dp radius, soft navy-tinted shadow, hairline border.
/// An optional [accentColor] draws the 4dp left-border severity accent (DS).
class SeaLankaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? borderRadius;
  final Color? accentColor;

  const SeaLankaCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderRadius,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius ?? AppSpacing.radiusCard);
    final surface = color ?? (isDark ? AppColors.cardDark : AppColors.cardLight);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: radius,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark ? null : AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (accentColor != null)
                  Container(width: 4, color: accentColor),
                Expanded(
                  child: Padding(
                    padding:
                        padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
