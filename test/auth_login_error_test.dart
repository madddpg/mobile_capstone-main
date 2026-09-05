import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/auth/data/auth_login_error.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';

void main() {
  group('authLoginErrorMessage', () {
    test(
      'maps wrong password and sibling credential codes to one clear line',
      () {
        expect(
          authLoginErrorMessage('wrong-password'),
          'Incorrect email or password.',
        );
        expect(
          authLoginErrorMessage('invalid-credential'),
          'Incorrect email or password.',
        );
        expect(
          authLoginErrorMessage('user-not-found'),
          'Incorrect email or password.',
        );
      },
    );

    test('maps lockout, disabled, and offline codes', () {
      expect(
        authLoginErrorMessage('too-many-requests'),
        contains('Too many attempts'),
      );
      expect(authLoginErrorMessage('user-disabled'), contains('disabled'));
      expect(
        authLoginErrorMessage('network-request-failed'),
        contains('offline'),
      );
    });

    test('maps INVALID_ARGUMENT style callable failures to a warning line', () {
      expect(
        callableUserMessage(
          'INVALID_ARGUMENT',
          message: 'INVALID_ARGUMENT',
          action: 'verify the code',
        ),
        'That code did not work. Check it, or request a new one.',
      );
      expect(
        callableUserMessage(
          'invalid-argument',
          message: 'Incorrect OTP code.',
          action: 'verify the code',
        ),
        'Incorrect OTP code.',
      );
      expect(
        callableUserMessage(
          'permission-denied',
          message: 'PERMISSION_DENIED',
          action: 'verify the code',
        ),
        'Could not verify the code right now. Try again in a moment.',
      );
    });

    test('reads userMessage from callable HTTP error details', () {
      final parsed = parseCallableHttpError({
        'code': 400,
        'status': 'INVALID_ARGUMENT',
        'message': 'INVALID_ARGUMENT',
        'details': [
          {'userMessage': 'Incorrect OTP code.'},
        ],
      });
      expect(parsed.code, 'INVALID_ARGUMENT');
      expect(parsed.message, 'Incorrect OTP code.');
    });

    test('strips EmailApiException prefixes from SnackBar copy', () {
      expect(
        stripAuthExceptionPrefix(
          'EmailApiException: Incorrect email or password.',
        ),
        'Incorrect email or password.',
      );
      expect(
        stripAuthExceptionPrefix(
          'EmailApiException(401): Incorrect email or password.',
        ),
        'Incorrect email or password.',
      );
    });
  });

  group('ProjectLifecycle posting gates', () {
    test('posted estimates are not treated as still-planning', () {
      expect(
        ProjectLifecycle.isPosted(
          ProjectLifecycle.waitingForQuotations,
          postId: 'post-1',
        ),
        isTrue,
      );
      expect(ProjectLifecycle.isPlanning(ProjectLifecycle.planning), isTrue);
      expect(
        ProjectLifecycle.isPlanning(ProjectLifecycle.waitingForQuotations),
        isFalse,
      );
    });
  });
}
