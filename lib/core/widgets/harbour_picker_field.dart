import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/constants/sri_lanka_harbours.dart';
import 'package:sea_lanka/core/widgets/sl_bottom_sheet.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';

/// Read-only [SlTextField] that opens a bottom sheet listing every Sri
/// Lankan fishery harbour / fish landing site grouped by district, instead
/// of free text entry.
class HarbourPickerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const HarbourPickerField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
  });

  Future<void> _open(BuildContext context) async {
    final selected = await showHarbourPicker(context, current: controller.text);
    if (selected != null) controller.text = selected;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: AbsorbPointer(
        child: SlTextField(
          controller: controller,
          label: label,
          hint: AppLocalizations.of(context)!.selectYourHomeHarbourHint,
          prefixIcon: Icons.anchor_outlined,
          suffix: const Icon(Icons.expand_more_rounded, size: 20),
          validator: validator,
        ),
      ),
    );
  }
}

/// Opens the same harbour-selection bottom sheet [HarbourPickerField] uses,
/// for callers that just want the picked value directly (e.g. a settings
/// row) rather than binding it to a text field.
Future<String?> showHarbourPicker(BuildContext context, {String? current}) {
  return showSlBottomSheet<String>(
    context: context,
    builder: (ctx) => _HarbourList(current: current ?? ''),
  );
}

class _HarbourList extends StatefulWidget {
  final String current;
  const _HarbourList({required this.current});

  @override
  State<_HarbourList> createState() => _HarbourListState();
}

class _HarbourListState extends State<_HarbourList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = _query.trim().toLowerCase();

    final entries = <MapEntry<String, List<String>>>[];
    for (final district in SriLankaHarbours.byDistrict.entries) {
      final matches = q.isEmpty
          ? district.value
          : district.value
              .where((h) => h.toLowerCase().contains(q) ||
                  district.key.toLowerCase().contains(q))
              .toList();
      if (matches.isNotEmpty) entries.add(MapEntry(district.key, matches));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocalizations.of(context)!.selectHomeHarbourTitle,
              style: AppTextStyles.h3(locale).copyWith(
                  color: isDark ? AppColors.fgOnDark : AppColors.fg1)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _query = v),
            style: AppTextStyles.body(locale).copyWith(
                color: isDark ? AppColors.fgOnDark : AppColors.fg1),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchHarbourOrDistrictHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final district in entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs),
                    child: Text(district.key,
                        style: AppTextStyles.caption(locale).copyWith(
                          color: AppColors.marineBlue,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  for (final harbour in district.value)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(harbour,
                          style: AppTextStyles.body(locale).copyWith(
                              color: isDark
                                  ? AppColors.fgOnDark
                                  : AppColors.fg1)),
                      trailing: harbour == widget.current
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.marineBlue, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).pop(harbour),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
