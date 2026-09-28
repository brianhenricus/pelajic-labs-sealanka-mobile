import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';

/// "A Pelajic Labs Product" footer. Required on splash, about, settings (DS).
class Attribution extends StatelessWidget {
  final Color? color;
  const Attribution({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Text(
      'A Pelajic Labs Product',
      textAlign: TextAlign.center,
      style: AppTextStyles.caption(locale).copyWith(
        color: color ?? AppColors.fg3,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
