import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_pressable.dart';

/// Probability tier for a fishing zone.
enum ProbabilityTier { high, medium, low }

extension ProbabilityTierX on ProbabilityTier {
  Gradient get gradient => switch (this) {
        ProbabilityTier.high => AppColors.probHighGradient,
        ProbabilityTier.medium => AppColors.probMidGradient,
        ProbabilityTier.low => AppColors.probLowGradient,
      };

  String get label => switch (this) {
        ProbabilityTier.high => 'HIGH PROBABILITY',
        ProbabilityTier.medium => 'MEDIUM PROBABILITY',
        ProbabilityTier.low => 'LOW PROBABILITY',
      };

  /// Maps a 0–100 probability to a tier (DS: high ≥80, medium ≥50).
  static ProbabilityTier fromPercent(num pct) {
    if (pct >= 80) return ProbabilityTier.high;
    if (pct >= 50) return ProbabilityTier.medium;
    return ProbabilityTier.low;
  }
}

/// Probability-gradient zone card. Maps to the React `ZoneTile` component.
class ZoneTile extends StatelessWidget {
  final ProbabilityTier tier;
  final String name;
  final int percent;
  final String? direction;
  final String? distance;
  final VoidCallback? onTap;

  const ZoneTile({
    super.key,
    required this.tier,
    required this.name,
    required this.percent,
    this.direction,
    this.distance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final meta = [
      if (direction != null) direction!,
      if (distance != null) distance!,
    ].join(' · ');

    return SeaLankaPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: tier.gradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tier.label,
              style: AppTextStyles.overline(locale)
                  .copyWith(color: Colors.white.withOpacity(0.9)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  name,
                  style: AppTextStyles.h3(locale)
                      .copyWith(color: Colors.white),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: AppTextStyles.h1(locale)
                      .copyWith(color: Colors.white),
                ),
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                meta,
                style: AppTextStyles.caption(locale)
                    .copyWith(color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
