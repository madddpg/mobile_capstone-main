import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/bidding/data/post_load_outcome.dart';

/// Decides whether a broken estimate screen offers a retry or an unlink.
///
/// Getting this wrong in one direction leaves builders stuck retrying a post
/// that will never load. Getting it wrong in the other offers to change their
/// saved project over what was only a dropped connection.
void main() {
  group('classifyPostLoad', () {
    test('a readable post that exists loads', () {
      expect(
        classifyPostLoad(hasError: false, exists: true),
        PostLoadOutcome.loaded,
      );
    });

    test('a post that is missing is unavailable, not a retry', () {
      expect(
        classifyPostLoad(hasError: false, exists: false),
        PostLoadOutcome.unavailable,
      );
    });

    test('permission-denied is unavailable', () {
      // For a builder, a deleted post arrives as permission-denied, because
      // the ownership rule errors on a document that is not there.
      expect(
        classifyPostLoad(
          hasError: true,
          errorCode: 'permission-denied',
          exists: false,
        ),
        PostLoadOutcome.unavailable,
      );
    });

    test('not-found is unavailable', () {
      expect(
        classifyPostLoad(hasError: true, errorCode: 'not-found', exists: false),
        PostLoadOutcome.unavailable,
      );
    });

    test('network failures are offline, so they offer a retry', () {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      ]) {
        expect(
          classifyPostLoad(hasError: true, errorCode: code, exists: false),
          PostLoadOutcome.offline,
          reason: 'code $code',
        );
      }
    });

    test('an unrecognised error offers a retry rather than an unlink', () {
      for (final code in ['internal', 'aborted', null]) {
        expect(
          classifyPostLoad(hasError: true, errorCode: code, exists: false),
          PostLoadOutcome.failed,
          reason: 'code $code',
        );
      }
    });

    test('being signed out never offers to unlink', () {
      // Unlinking needs a signed-in account and would fail anyway; the right
      // answer is to try again after signing back in.
      expect(
        classifyPostLoad(
          hasError: true,
          errorCode: 'unauthenticated',
          exists: false,
        ),
        PostLoadOutcome.failed,
      );
    });
  });

  group('firestoreErrorCode', () {
    test('an error that is not a Firestore exception has no code', () {
      expect(firestoreErrorCode(StateError('boom')), isNull);
      expect(firestoreErrorCode(null), isNull);
    });
  });
}
