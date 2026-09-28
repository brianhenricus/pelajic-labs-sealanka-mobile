import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_pressable.dart';

/// Button variants:
/// - [primary]   marine-blue fill (default action)
/// - [cta]       coral-gold gradient fill (the next action only — DS rule)
/// - [secondary] coral-gold solid fill
/// - [outline]   marine-blue outline
/// - [ghost]     text only
enum SeaLankaButtonVariant { primary, cta, secondary, outline, ghost }

class SeaLankaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SeaLankaButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final bool trailingIcon;
  final double? height;

  const SeaLankaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SeaLankaButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
    this.trailingIcon = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = height ?? AppSpacing.buttonHeight;
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null && !trailingIcon) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
              if (icon != null && trailingIcon) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: 18),
              ],
            ],
          );

    final size = Size(fullWidth ? double.infinity : 0, h);

    switch (variant) {
      case SeaLankaButtonVariant.cta:
        return SeaLankaPressable(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          child: Container(
            width: fullWidth ? double.infinity : null,
            height: h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.ctaGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          ),
        );
      case SeaLankaButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(minimumSize: size),
          child: child,
        );
      case SeaLankaButtonVariant.secondary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.coralGold,
            foregroundColor: Colors.white,
            minimumSize: size,
          ),
          child: child,
        );
      case SeaLankaButtonVariant.outline:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            side: BorderSide(color: theme.colorScheme.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
          ),
          child: child,
        );
      case SeaLankaButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(minimumSize: size),
          child: child,
        );
    }
  }
}
