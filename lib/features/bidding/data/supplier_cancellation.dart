import 'package:cloud_functions/cloud_functions.dart';

/// Why a builder is cancelling a supplier they already selected.
///
/// The keys travel to the Cloud Function and must match the list in
/// `functions/src/services/supplierSelection.js`. The labels are what the
/// builder taps; the shop is shown the server's wording of the same reason.
enum CancelReason {
  shopUnresponsive,
  cannotSupply,
  priceChanged,
  choseAnotherShop,
  mistake,
}

extension CancelReasonDetails on CancelReason {
  String get key => switch (this) {
        CancelReason.shopUnresponsive => 'shop_unresponsive',
        CancelReason.cannotSupply => 'cannot_supply',
        CancelReason.priceChanged => 'price_changed',
        CancelReason.choseAnotherShop => 'chose_another_shop',
        CancelReason.mistake => 'mistake',
      };

  String get label => switch (this) {
        CancelReason.shopUnresponsive => 'They stopped replying',
        CancelReason.cannotSupply => 'They cannot supply the materials',
        CancelReason.priceChanged => 'They changed the price',
        CancelReason.choseAnotherShop => 'I am going with another shop',
        CancelReason.mistake => 'I selected the wrong shop',
      };
}

/// Cancels a supplier selection through the Cloud Function that owns the
/// policy.
///
/// The client cannot do this itself: reopening an estimate puts the other
/// shops' quotations back on the table, and a builder may not write to those.
class SupplierCancellationService {
  SupplierCancellationService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  /// Returns how many quotations went back on the table.
  Future<int> cancel({
    required String postId,
    required CancelReason reason,
    String note = '',
  }) async {
    final callable = _functions.httpsCallable(
      'cancelSupplierSelection',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final response = await callable.call(<String, dynamic>{
      'postId': postId,
      'reason': reason.key,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    });

    final data = response.data;
    if (data is Map && data['restored'] is num) {
      return (data['restored'] as num).toInt();
    }
    return 0;
  }

  /// What went wrong, in words a builder can act on.
  ///
  /// The server's own messages are already written for the builder, so a
  /// refusal it explains is passed through rather than replaced.
  static String friendlyError(FirebaseFunctionsException error) {
    final message = (error.message ?? '').trim();
    return switch (error.code.toLowerCase()) {
      'unauthenticated' => 'Sign in again to cancel this selection.',
      'permission-denied' => 'That estimate is not yours to change.',
      'not-found' => 'That estimate or quotation no longer exists.',
      'failed-precondition' || 'invalid-argument' =>
        message.isEmpty ? 'That selection cannot be cancelled.' : message,
      'unavailable' || 'deadline-exceeded' =>
        'Could not reach the server. Check your connection and try again.',
      _ => message.isEmpty
          ? 'That cancellation did not go through. Try again.'
          : message,
    };
  }
}

/// What the builder chose in the cancellation sheet.
class CancelSelectionChoice {
  final CancelReason reason;
  final String note;

  const CancelSelectionChoice({required this.reason, this.note = ''});
}
