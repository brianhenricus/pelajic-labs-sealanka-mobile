import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OtpInputWidget extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;

  const OtpInputWidget({
    super.key,
    this.length = 6,
    required this.onCompleted,
  });

  @override
  State<OtpInputWidget> createState() => _OtpInputWidgetState();
}

// CodeAutoFill (from the sms_autofill package) wires up:
// - Android: the SMS User Consent API -- a native one-tap consent sheet,
//   no app-hash embedded in the SMS text required (unlike the older SMS
//   Retriever API), works with any plain OTP message.
// - iOS: textContentType: .oneTimeCode (set via autofillHints below),
//   which iOS's own keyboard suggestion bar already reads from Messages.
class _OtpInputWidgetState extends State<OtpInputWidget> with CodeAutoFill {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    for (final f in _focusNodes) {
      f.addListener(_onFocusChanged);
    }
    listenForCode();
  }

  void _onFocusChanged() => setState(() {});

  @override
  void codeUpdated() {
    final autoCode = code;
    if (autoCode == null) return;
    _fillCode(autoCode);
  }

  /// Distributes a full code (from SMS autofill, or a manual paste into
  /// any single box) across all controllers at once, instead of relying on
  /// each box's own single-character onChanged.
  void _fillCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < widget.length) return;
    final code = digits.substring(digits.length - widget.length);
    for (var i = 0; i < widget.length; i++) {
      _controllers[i].text = code[i];
    }
    setState(() {});
    widget.onCompleted(code);
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    // A paste landing in a single box (long-press paste, or a keyboard
    // autofill suggestion tapped into one field) delivers the whole code
    // at once here, not one digit at a time.
    if (value.length > 1) {
      _fillCode(value);
      return;
    }
    if (value.length == 1 && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == widget.length) {
      widget.onCompleted(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        final isFilled = _controllers[i].text.isNotEmpty;
        final isActive = _focusNodes[i].hasFocus;
        final Color borderColor = isActive
            ? AppColors.coralGold
            : isFilled
                ? AppColors.midnightNavy
                : AppColors.borderLight;
        return SizedBox(
          width: 46,
          height: 56,
          child: TextFormField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            // Only the first box declares the one-time-code hint -- that's
            // the field iOS's suggestion bar and Android's Autofill
            // framework actually target for a short SMS-code sequence.
            autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
            style: AppTextStyles.h2(locale).copyWith(
              color: isFilled ? AppColors.white : AppColors.fg1,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor:
                  isFilled ? AppColors.midnightNavy : AppColors.cardLight,
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide:
                    BorderSide(color: borderColor, width: isFilled ? 1.5 : 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide: BorderSide(color: borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                borderSide:
                    const BorderSide(color: AppColors.coralGold, width: 2),
              ),
            ),
            onChanged: (v) => _onChanged(i, v),
          ),
        );
      }),
    );
  }
}
