/// User-facing copy for Firebase Auth sign-in failures.
String authLoginErrorMessage(String code, {String? fallback}) {
  switch (code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-email':
      return 'Incorrect email or password.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a moment and try again.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'network-request-failed':
      return 'You appear to be offline. Check your connection and try again.';
    default:
      final detail = fallback?.trim();
      if (detail != null && detail.isNotEmpty) {
        return 'Could not sign in. $detail';
      }
      return 'Could not sign in. Please try again.';
  }
}

/// Strips exception class prefixes so SnackBars show only the message.
String stripAuthExceptionPrefix(Object error) {
  return error
      .toString()
      .replaceFirst(RegExp(r'^EmailApiException(\(\d+\))?: '), '')
      .replaceFirst('EmailApiException: ', '');
}

/// Maps Cloud Functions codes (and gRPC-style messages like INVALID_ARGUMENT)
/// to builder-facing copy.
String callableUserMessage(
  String code, {
  String? message,
  required String action,
}) {
  final detail = message?.trim();
  final usableDetail =
      detail != null && detail.isNotEmpty && !_isMachineStatus(detail)
      ? detail
      : null;

  switch (code.toLowerCase().replaceAll('_', '-')) {
    case 'invalid-argument':
      return usableDetail ??
          'That code did not work. Check it, or request a new one.';
    case 'not-found':
      return usableDetail ??
          'No verification code was found. Request a new one.';
    case 'deadline-exceeded':
      return usableDetail ??
          'This code has expired. Please request a new one.';
    case 'resource-exhausted':
      return usableDetail ??
          'Too many attempts. Please request a new code.';
    case 'failed-precondition':
      return usableDetail ??
          'Please wait a moment before requesting another code.';
    case 'unauthenticated':
    case 'permission-denied':
    case 'unavailable':
    case 'internal':
      return 'Could not $action right now. Try again in a moment.';
    default:
      return usableDetail ?? 'Could not $action. Please try again.';
  }
}

bool _isMachineStatus(String text) {
  return RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(text);
}

/// Reads `status` / `message` / `userMessage` from a callable HTTP error body.
({String code, String? message}) parseCallableHttpError(Object? errorField) {
  if (errorField is! Map) {
    return (code: 'internal', message: null);
  }

  final status = errorField['status'] ?? errorField['code'];
  final code = status == null ? 'internal' : status.toString();
  String? message = errorField['message']?.toString();
  final details = errorField['details'];
  if (details is List) {
    for (final item in details) {
      if (item is Map && item['userMessage'] is String) {
        final userMessage = (item['userMessage'] as String).trim();
        if (userMessage.isNotEmpty) {
          message = userMessage;
          break;
        }
      }
    }
  } else if (details is Map && details['userMessage'] is String) {
    final userMessage = (details['userMessage'] as String).trim();
    if (userMessage.isNotEmpty) {
      message = userMessage;
    }
  }

  return (code: code, message: message);
}
