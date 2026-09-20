"use strict";

/**
 * Cancelling a supplier selection.
 *
 * Accepting a quotation is a commitment, not a draft: the other shops are
 * told they lost in the same transaction, a conversation opens, and the shop
 * may set stock aside. So there is no undo, which would rewrite a record both
 * sides already acted on. There is a cancellation instead — a new fact, with
 * a reason, that the shop is told about and that reopens the estimate.
 *
 * The pure parts live here so the policy can be tested without the emulator.
 */

/** Reasons a builder can give, and how each reads to the shop. */
const CANCEL_REASONS = {
  shop_unresponsive: "The shop stopped replying",
  cannot_supply: "The shop could not supply the materials",
  price_changed: "The price changed after the quotation",
  chose_another_shop: "The builder went with another shop",
  mistake: "The wrong shop was selected by mistake",
};

/** The reason key, or null when it is not one of ours. */
function normalizeCancelReason(raw) {
  const key = String(raw || "").trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(CANCEL_REASONS, key)
    ? key
    : null;
}

function cancelReasonLabel(key) {
  return CANCEL_REASONS[key] || "No reason given";
}

/** A builder's own words, trimmed and capped so a note cannot be an essay. */
function sanitizeCancelNote(raw) {
  const text = String(raw || "").trim();
  if (!text) return "";
  return text.length > 500 ? `${text.slice(0, 499)}…` : text;
}

/**
 * Quotations that go back on the table.
 *
 * Accepting one quotation rejects its siblings, so cancelling has to put them
 * back or the builder is left with an open estimate and nothing to choose
 * from. Only `rejected` ones are restored: a quotation the shop itself
 * withdrew, or one already cancelled, stays as it is.
 */
function restorableQuotationIds(quotations, cancelledId) {
  return quotations
    .filter(
      (q) =>
        q.id !== cancelledId &&
        String(q.status || "").trim().toLowerCase() === "rejected"
    )
    .map((q) => q.id);
}

/** Where the estimate lands once the selection is gone. */
function reopenedPostStatus(restoredCount) {
  return restoredCount > 0 ? "has_quotations" : "open";
}

/** Where the builder's saved estimate lands. Mirrors ProjectLifecycle. */
function reopenedProjectStatus(restoredCount) {
  return restoredCount > 0 ? "receiving quotations" : "waiting for quotations";
}

/** What the shop is told. Their own cancellation is not news to them. */
function cancellationMessage({ projectName, reasonKey, note }) {
  const project = String(projectName || "").trim() || "an estimate";
  const reason = cancelReasonLabel(reasonKey);
  const tail = note ? ` They added: "${note}"` : "";
  return `The builder cancelled your selection on ${project}. Reason: ${reason}.${tail}`;
}

module.exports = {
  CANCEL_REASONS,
  normalizeCancelReason,
  cancelReasonLabel,
  sanitizeCancelNote,
  restorableQuotationIds,
  reopenedPostStatus,
  reopenedProjectStatus,
  cancellationMessage,
};
