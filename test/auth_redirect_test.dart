import 'package:ecommerce/core/utils/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAuthRedirectUrl', () {
    test('returns null when empty', () {
      expect(normalizeAuthRedirectUrl(''), isNull);
    });

    test('returns null when whitespace', () {
      expect(normalizeAuthRedirectUrl('   '), isNull);
    });

    test('returns trimmed when non-empty', () {
      expect(
        normalizeAuthRedirectUrl('  myapp://reset  '),
        'myapp://reset',
      );
    });
  });
}

