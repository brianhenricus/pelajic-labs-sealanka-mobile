import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';

/// Pill segmented control (e.g. Currents | Tides, plan billing toggle).
/// Maps to the chip/segment pattern in `components-inputs.html`.
class SlSegmented extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SlSegmented({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? Colors.white.withOpacity(0.08) : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        children: List.generate(segments.length, (i) {
          final active = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: active ? AppColors.marineBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                alignment: Alignment.center,
                child: Text(
                  segments[i],
                  style: AppTextStyles.body(locale).copyWith(
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white
                        : (isDark ? AppColors.fgOnDark2 : AppColors.fg2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
