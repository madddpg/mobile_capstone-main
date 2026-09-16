/// The status a builder should see for a quotation.
///
/// A builder's acceptance is written in two places in one transaction: the
/// quotation's `status`, and `selectedQuotationId` on the estimate. Only the
/// estimate is the builder's own document, so it is the one trusted here. A
/// quotation that claims to be accepted while the estimate selected nothing,
/// or selected a different quotation, is shown as an ordinary open offer.
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
  if (status.isEmpty) return 'pending';

  final claimsAcceptance =
      status == 'accepted' || status == 'partially_accepted';
  if (!claimsAcceptance) return status;

  final selected = selectedQuotationId?.trim() ?? '';
  return selected.isNotEmpty && selected == quotationId ? status : 'submitted';
}
