import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/core/validation/password_policy.dart';

void main() {
  group('PasswordPolicy.validate', () {
    test('accepts a password meeting every requirement', () {
      expect(PasswordPolicy.validate('Renovate2026'), isNull);
    });

    test('reports the first unmet requirement so the hint is actionable', () {
      expect(PasswordPolicy.validate(''), 'Password is required');
      expect(PasswordPolicy.validate('Ab1cd'), 'Use at least 8 characters');
      expect(
        PasswordPolicy.validate('lowercase1'),
        'Add an uppercase letter',
      );
      expect(
        PasswordPolicy.validate('UPPERCASE1'),
        'Add a lowercase letter',
      );
      expect(PasswordPolicy.validate('NoDigitsHere'), 'Add a number');
    });

    test('rejects the old six-character minimum', () {
      expect(PasswordPolicy.validate('Abc123'), isNotNull);
    });

    test('rejects common passwords that pass the character rules', () {
      expect(PasswordPolicy.validate('Password123'), contains('too common'));
      expect(PasswordPolicy.validate('Passw0rd'), contains('too common'));
    });

    test('rejects surrounding whitespace that users cannot see', () {
      expect(
        PasswordPolicy.validate('Renovate2026 '),
        'Password cannot start or end with a space',
      );
    });
  });

  group('PasswordPolicy.validateConfirmation', () {
    test('passes when both entries match', () {
      expect(
        PasswordPolicy.validateConfirmation('Renovate2026', 'Renovate2026'),
        isNull,
      );
    });

    test('flags an empty or mismatched confirmation', () {
      expect(
        PasswordPolicy.validateConfirmation('Renovate2026', ''),
        'Confirm your password',
      );
      expect(
        PasswordPolicy.validateConfirmation('Renovate2026', 'Renovate2025'),
        'Passwords do not match',
      );
    });
  });
}
