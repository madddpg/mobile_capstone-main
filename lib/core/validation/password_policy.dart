/// Single source of truth for password strength across registration, reset and
/// change-password.
///
/// Only applies to screens where a password is *chosen*. Sign-in must keep
/// accepting existing passwords so accounts created under the old 6-character
/// rule are not locked out.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minLength = 8;

  static const String hint =
      'At least 8 characters with an uppercase letter, a lowercase letter and a number.';

  /// Rejected outright because they are the first guesses in any credential
  /// stuffing list, even though they satisfy the character rules.
  static const Set<String> _commonPasswords = {
    'password',
    'password1',
    'password123',
    'passw0rd',
    'qwerty123',
    'iconstruct',
    'iconstruct1',
    'abcd1234',
    'admin123',
    '12345678',
    'welcome1',
  };

  /// Returns an actionable message for the first unmet requirement, or null
  /// when [password] is acceptable.
  static String? validate(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.trim().length != password.length) {
      return 'Password cannot start or end with a space';
    }
    if (password.length < minLength) {
      return 'Use at least $minLength characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Add an uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Add a lowercase letter';
    }
    if (!password.contains(RegExp(r'\d'))) {
      return 'Add a number';
    }
    if (_commonPasswords.contains(password.toLowerCase())) {
      return 'This password is too common. Choose something harder to guess';
    }
    return null;
  }

  /// Confirmation field check, kept here so the copy stays consistent.
  static String? validateConfirmation(String password, String confirmation) {
    if (confirmation.isEmpty) return 'Confirm your password';
    if (confirmation != password) return 'Passwords do not match';
    return null;
  }
}
