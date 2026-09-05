import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// User-facing copy for common backend failures (rules, auth, network).
///
/// [action] completes the sentence `Could not ...`, so pass a verb phrase such
/// as `'save your estimate'`.
String firestoreUserMessage(Object error, {required String action}) {
  final code = error is FirebaseException ? error.code : null;

  if (kDebugMode) {
    debugPrint('Firestore error while trying to $action: $error');
  }

  switch (code) {
    case 'permission-denied':
      if (FirebaseAuth.instance.currentUser == null) {
        return 'Your session expired. Please log in again to $action.';
      }
      return "You don't have permission to $action.";

    case 'unauthenticated':
      return 'Your session expired. Please log in again to $action.';

    case 'unavailable':
    case 'network-request-failed':
      return 'You appear to be offline. Check your connection and try again.';

    case 'deadline-exceeded':
      return 'That took too long. Please try again.';

    case 'not-found':
      return 'That item no longer exists. Try refreshing.';

    case 'already-exists':
      return 'That item already exists.';

    case 'aborted':
    case 'failed-precondition':
      return 'Something changed while you were working. Refresh and try again.';

    case 'resource-exhausted':
      return 'Too many requests right now. Please wait a moment and try again.';

    case 'cancelled':
      return 'That action was cancelled.';
  }

  if (error is FirebaseAuthException) {
    return 'Could not $action. Please try again.';
  }

  return 'Could not $action. Please try again.';
}
