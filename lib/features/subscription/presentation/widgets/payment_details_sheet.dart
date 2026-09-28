import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';

/// Card-details form shown before subscribing to (or switching to) a paid
/// plan. No real payment gateway is integrated yet (backend's
/// SubscribeRequest.payment_method_token is accepted-and-ignored, see
/// sealanka-be's schemas/subscription.py) -- this only collects a plausible
/// card and hands back a locally-generated placeholder token, never a real
/// PAN. Its purpose is UX completeness for the flow now, not processing a
/// charge; swap in a real gateway SDK here once one is chosen.
Future<String?> showPaymentDetailsSheet({
  required BuildContext context,
  required String planName,
  required String priceLabel,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _PaymentDetailsForm(planName: planName, priceLabel: priceLabel),
    ),
  );
}

class _PaymentDetailsForm extends StatefulWidget {
  final String planName;
  final String priceLabel;
  const _PaymentDetailsForm({required this.planName, required this.priceLabel});

  @override
  State<_PaymentDetailsForm> createState() => _PaymentDetailsFormState();
}

class _PaymentDetailsFormState extends State<_PaymentDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String? _validateCard(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13 || digits.length > 19) {
      return 'Enter a valid card number';
    }
    return null;
  }

  String? _validateExpiry(String? v) {
    final match =
        RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').firstMatch((v ?? '').trim());
    if (match == null) return 'MM/YY';
    return null;
  }

  String? _validateCvv(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 3 || digits.length > 4) return 'Enter CVV';
    return null;
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    // A placeholder, never the real PAN -- see the file docstring. Only
    // the last 4 digits and a session-local marker, purely so the backend
    // call has *something* non-null to log against for now.
    final digits = _cardController.text.replaceAll(RegExp(r'\D'), '');
    final last4 =
        digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    Navigator.of(context).pop('local-placeholder-$last4');
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
              Text(t.paymentDetailsTitle,
                  style:
                      AppTextStyles.h2(locale).copyWith(color: AppColors.fg1)),
              const SizedBox(height: 4),
              Text('${widget.planName} · ${widget.priceLabel}',
                  style: AppTextStyles.body(locale).copyWith(
                      color: AppColors.marineBlue,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text(t.paymentDetailsSubtitle,
                  style: AppTextStyles.caption(locale)
                      .copyWith(color: AppColors.fg3)),
              const SizedBox(height: AppSpacing.lg),
              SlTextField(
                controller: _nameController,
                label: t.cardholderNameLabel,
                hint: 'A. Perera',
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SlTextField(
                controller: _cardController,
                label: t.cardNumberLabel,
                hint: '4111 1111 1111 1111',
                prefixIcon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                validator: _validateCard,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SlTextField(
                      controller: _expiryController,
                      label: t.expiryLabel,
                      hint: '12/28',
                      keyboardType: TextInputType.number,
                      validator: _validateExpiry,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SlTextField(
                      controller: _cvvController,
                      label: t.cvvLabel,
                      hint: '123',
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      validator: _validateCvv,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SeaLankaButton(
                label: t.confirmAndPayCta,
                variant: SeaLankaButtonVariant.cta,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
