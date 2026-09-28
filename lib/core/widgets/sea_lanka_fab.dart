import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_shadows.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_pressable.dart';

/// 56dp circular FAB with the CTA gold gradient and sky-blue glow shadow.
/// The single attention-pulling control on a screen (DS rule).
class SeaLankaFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const SeaLankaFab({
    super.key,
    this.icon = Icons.add,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final fab = SeaLankaPressable(
      onTap: onPressed,
      child: Container(
        width: AppSpacing.fabSize,
        height: AppSpacing.fabSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.ctaGradient,
          boxShadow: AppShadows.fab,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
    return tooltip == null ? fab : Tooltip(message: tooltip!, child: fab);
  }
}
