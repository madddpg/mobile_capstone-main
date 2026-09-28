/// The status a builder should see for a quotation.
///
/// A builder's acceptance is written in two places in one transaction: the
/// quotation's `status`, and `selectedQuotationId` on the estimate. Only the
/// estimate is the builder's own document, so it is the one trusted here.
///
/// It is trusted in both directions. A quotation that claims to be accepted
/// while the estimate selected nothing, or selected a different quotation, is
/// shown as an ordinary open offer. A quotation the estimate *did* select
/// shows as accepted even if its own status was never updated, which happens
/// when the second half of the acceptance did not land. The card used to show
/// "Pending" and "Selected supplier" at once and leave the builder to guess.
///
/// The security rules already stop a shop writing such a quotation. This keeps
/// a document written some other way, such as through the Admin SDK, from
/// showing an "Accepted" badge the builder never gave, or from hiding the
/// "Select shop" button on a real offer.
String displayQuotationStatus({
  required String? rawStatus,
  required String quotationId,
  required String? selectedQuotationId,
}) {
  final status = (rawStatus ?? '').trim().toLowerCase();
  final selected = selectedQuotationId?.trim() ?? '';
  final isSelected = selected.isNotEmpty && selected == quotationId;

  if (isSelected) {
    return status == 'partially_accepted' ? status : 'accepted';
  }
  if (status.isEmpty) return 'pending';

  final claimsAcceptance =
      status == 'accepted' || status == 'partially_accepted';
  return claimsAcceptance ? 'submitted' : status;
}

/// Whether a quotation is still an offer the builder has not decided on.
///
/// The shop dashboard files new offers as `pending`; the app and a
/// cancellation that reopens an estimate use `submitted`. Anything else is
/// already a decision — accepted, turned down, cancelled, withdrawn — and
/// choosing another shop must not rewrite it.
bool isOpenOfferStatus(String? rawStatus) {
  final status = (rawStatus ?? '').trim().toLowerCase();
  return status.isEmpty || status == 'pending' || status == 'submitted';
}

/// Whether the quotation still has to be marked accepted to match the estimate.
///
/// Chat, and everything else the rules gate on acceptance, reads the
/// quotation's own status. When the estimate selected this quotation but that
/// write never landed, the builder is refused permission to message the shop
/// they just chose. The fix is to finish the write, not to explain the error.
bool quotationNeedsStatusRepair({
  required String? rawStatus,
  required String quotationId,
  required String? selectedQuotationId,
}) {
  final selected = selectedQuotationId?.trim() ?? '';
  if (selected.isEmpty || selected != quotationId) return false;
  final status = (rawStatus ?? '').trim().toLowerCase();
  return status != 'accepted' && status != 'partially_accepted';
}
