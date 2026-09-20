import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/bidding/data/supplier_cancellation.dart';

void main() {
  group('CancelReason', () {
    test('every reason the app offers is one the server accepts', () {
      // A key the function does not know is rejected as invalid-argument, and
      // the builder sees "pick a reason" after already picking one. The two
      // lists are in different languages, so this reads the server's.
      final server =
          File('functions/src/services/supplierSelection.js').readAsStringSync();
      for (final reason in CancelReason.values) {
        expect(
          server.contains('${reason.key}:'),
          isTrue,
          reason: 'the function has no reason named ${reason.key}',
        );
      }
    });

    test('the keys are stable snake_case, not enum names', () {
      expect(CancelReason.shopUnresponsive.key, 'shop_unresponsive');
      expect(CancelReason.choseAnotherShop.key, 'chose_another_shop');
      expect(CancelReason.mistake.key, 'mistake');
    });

    test('labels are what a builder would say, not a status code', () {
      for (final reason in CancelReason.values) {
        expect(reason.label, isNotEmpty);
        expect(reason.label, isNot(contains('_')));
      }
      expect(CancelReason.shopUnresponsive.label, 'They stopped replying');
    });
  });

  group('friendlyError', () {
    FirebaseFunctionsException error(String code, [String message = '']) =>
        FirebaseFunctionsException(code: code, message: message);

    test('a refusal the server explained is passed through', () {
      expect(
        SupplierCancellationService.friendlyError(
          error(
            'failed-precondition',
            'This estimate has already had a cancellation.',
          ),
        ),
        'This estimate has already had a cancellation.',
      );
    });

    test('a refusal with no words still says something useful', () {
      expect(
        SupplierCancellationService.friendlyError(error('failed-precondition')),
        'That selection cannot be cancelled.',
      );
    });

    test('being signed out and being blocked read differently', () {
      expect(
        SupplierCancellationService.friendlyError(error('unauthenticated')),
        contains('Sign in'),
      );
      expect(
        SupplierCancellationService.friendlyError(error('permission-denied')),
        contains('not yours'),
      );
    });

    test('a network failure tells the builder to try again', () {
      expect(
        SupplierCancellationService.friendlyError(error('unavailable')),
        contains('try again'),
      );
    });
  });

  group('CancelSelectionChoice', () {
    test('a note is optional', () {
      const choice = CancelSelectionChoice(reason: CancelReason.mistake);
      expect(choice.note, isEmpty);
      expect(choice.reason, CancelReason.mistake);
    });
  });
}
