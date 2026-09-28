import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_motion.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';

enum DataStatus { live, cached, offline }

/// Status pill (Live / Cached / Offline). The live dot gently pulses (DS).
/// Maps to the React `StatusBadge` component.
class DataStatusBadge extends StatefulWidget {
  final DataStatus status;

  /// Optional trailing detail, e.g. "2m ago" → "CACHED · 2M AGO".
  final String? detail;

  const DataStatusBadge({super.key, required this.status, this.detail});

  @override
  State<DataStatusBadge> createState() => _DataStatusBadgeState();
}

class _DataStatusBadgeState extends State<DataStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: AppMotion.pulse)..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final (label, color) = switch (widget.status) {
      DataStatus.live => ('LIVE', AppColors.success),
      DataStatus.cached => ('CACHED', AppColors.warning),
      DataStatus.offline => ('OFFLINE', AppColors.danger),
    };
    final text = widget.detail == null
        ? label
        : '$label · ${widget.detail!.toUpperCase()}';

    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (widget.status == DataStatus.live) {
      dot = FadeTransition(opacity: _pulse, child: dot);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 4),
          Text(text, style: AppTextStyles.overline(locale).copyWith(color: color)),
        ],
      ),
    );
  }
}
