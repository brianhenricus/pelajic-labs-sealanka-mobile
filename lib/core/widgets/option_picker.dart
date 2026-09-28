import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/widgets/sl_bottom_sheet.dart';

/// Simple single-choice bottom sheet for a short, fixed list of options
/// (language, units) -- lighter than [HarbourPickerField]'s searchable list
/// since these lists are only a handful of items.
Future<String?> showOptionPicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String current,
}) {
  return showSlBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final locale = Localizations.localeOf(ctx);
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: AppTextStyles.h3(locale).copyWith(
                    color: isDark ? AppColors.fgOnDark : AppColors.fg1)),
            const SizedBox(height: AppSpacing.sm),
            for (final option in options)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(option,
                    style: AppTextStyles.body(locale).copyWith(
                        color: isDark ? AppColors.fgOnDark : AppColors.fg1)),
                trailing: option == current
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.marineBlue, size: 20)
                    : null,
                onTap: () => Navigator.of(ctx).pop(option),
              ),
          ],
        ),
      );
    },
  );
}
