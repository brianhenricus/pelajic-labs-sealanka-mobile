import 'package:flutter_test/flutter_test.dart';
import 'package:sea_lanka/core/utils/phone_utils.dart';

void main() {
  group('normalizePhoneOrEmail', () {
    test('leading 0 becomes +94', () {
      expect(normalizePhoneOrEmail('0771234567'), '+94771234567');
    });

    test('bare number with no 0 gets +94 prepended', () {
      expect(normalizePhoneOrEmail('771234567'), '+94771234567');
    });

    test('already has a country code -- left alone', () {
      expect(normalizePhoneOrEmail('+94771234567'), '+94771234567');
      expect(normalizePhoneOrEmail('+447700900123'), '+447700900123');
    });

    test('email is never touched', () {
      expect(normalizePhoneOrEmail('user@example.com'), 'user@example.com');
    });

    test('trims surrounding whitespace and internal spaces in a phone number', () {
      expect(normalizePhoneOrEmail('  077 123 4567  '), '+94771234567');
    });

    test('empty input stays empty', () {
      expect(normalizePhoneOrEmail(''), '');
      expect(normalizePhoneOrEmail('   '), '');
    });
  });
}
