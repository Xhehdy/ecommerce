import 'package:ecommerce/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('returns message when empty', () {
      expect(validateEmail(''), isNotNull);
    });

    test('returns null when valid', () {
      expect(validateEmail('test@example.com'), isNull);
    });
  });

  group('validateNewPassword', () {
    test('returns message when empty', () {
      expect(validateNewPassword(''), isNotNull);
    });

    test('returns message when too short', () {
      expect(validateNewPassword('1234567'), isNotNull);
    });

    test('returns null when long enough', () {
      expect(validateNewPassword('12345678'), isNull);
    });
  });

  group('validateConfirmPassword', () {
    test('returns message when mismatch', () {
      expect(validateConfirmPassword('password123', 'password124'), isNotNull);
    });

    test('returns null when matches', () {
      expect(validateConfirmPassword('password123', 'password123'), isNull);
    });
  });
}

