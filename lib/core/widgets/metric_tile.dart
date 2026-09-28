import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';

/// Mini stat: icon + value + label. Used in the home "sea right now" grid,
/// forecast cards, profile stats. Maps to the React `Metric` component.
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const MetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor ?? AppColors.marineBlue),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: AppTextStyles.h3(locale).copyWith(
            color: isDark ? AppColors.fgOnDark : AppColors.fg1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption(locale).copyWith(
            color: isDark ? AppColors.fgOnDark2 : AppColors.fg3,
          ),
        ),
      ],
    );
  }
}
