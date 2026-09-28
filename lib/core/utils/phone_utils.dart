/// If [input] looks like an email (contains '@'), returns it unchanged
/// (trimmed) -- never touched as a phone number. Otherwise treats it as a
/// Sri Lankan phone number and normalizes it to E.164:
/// - a leading local-format `0` (e.g. `0771234567`) is replaced with `+94`
/// - a bare number with no leading `0` or `+` (e.g. `771234567`) gets `+94`
///   prepended
/// - anything that already carries a country code (`+94...` or another
///   `+...`) is left alone
String normalizePhoneOrEmail(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || trimmed.contains('@') || trimmed.startsWith('+')) {
    return trimmed;
  }
  final digits = trimmed.replaceAll(RegExp(r'\s'), '');
  if (digits.startsWith('0')) return '+94${digits.substring(1)}';
  return '+94$digits';
}
