"use strict";

/**
 * The official quotation invoice posted into the builder–shop chat.
 *
 * Accepting a quotation (whole or in part) is the deal: the invoice is issued
 * then, without waiting for the shop to confirm. The chat renders the message as a card with a PDF button; see
 * `TransactionInvoice.fromMessage` in
 * lib/features/chat/data/transaction_invoice.dart, which reads what is built
 * here.
 */

const ACCEPTED_STATUSES = ["accepted", "partially_accepted"];

/** The same list keys the app reads, in the same order (quotationItems()). */
const ITEM_KEYS = ["items", "materials", "lineItems", "quotedItems", "quotedMaterials"];

function amount(value) {
  if (typeof value === "number") return Number.isFinite(value) ? value : 0;
  const parsed = parseFloat(String(value ?? "").replace(/,/g, ""));
  return Number.isFinite(parsed) ? parsed : 0;
}

function quotationItems(data) {
  for (const key of ITEM_KEYS) {
    const raw = data && data[key];
    if (Array.isArray(raw) && raw.length > 0) {
      return raw.filter((item) => item && typeof item === "object");
    }
  }
  return [];
}

/** Mirrors lineTotalOf() in partial_acceptance.dart. */
function lineTotalOf(item) {
  const subtotal = amount(item.subtotal ?? item.lineTotal ?? item.total);
  if (subtotal > 0) return subtotal;
  const unitPrice = amount(item.unitPrice ?? item.price);
  const quantity = amount(item.quantity ?? item.qty);
  if (unitPrice > 0 && quantity > 0) return unitPrice * quantity;
  return unitPrice;
}

const UNAVAILABLE_STATUSES = new Set(["unavailable", "notavailable", "outofstock"]);

/** Mirrors isMarkedUnavailable() in partial_acceptance.dart. */
function isMarkedUnavailable(item) {
  const status = String(item.status ?? "").trim().toLowerCase().replace(/[\s_-]+/g, "");
  return UNAVAILABLE_STATUSES.has(status) || item.available === false;
}

/** The lines the builder took: not dropped, not unavailable, priced. */
function keptLines(quotation) {
  return quotationItems(quotation).filter(
    (item) => item.accepted !== false && !isMarkedUnavailable(item) && lineTotalOf(item) > 0
  );
}

/**
 * The total on the invoice. A partial acceptance stores the builder's
 * `acceptedTotal`; otherwise it is the sum of the kept lines, then the
 * shop's own quoted total for a lump-sum quotation with no lines.
 */
function invoiceTotal(quotation) {
  const stored = quotation.acceptedTotal;
  let total;
  if (typeof stored === "number" && stored > 0) {
    total = stored;
  } else {
    const lines = keptLines(quotation);
    total = lines.length > 0
      ? lines.reduce((sum, item) => sum + lineTotalOf(item), 0)
      : amount(quotation.totalAmount ?? quotation.total ?? quotation.estimatedTotal ?? quotation.amount);
  }
  return Math.round(total * 100) / 100;
}

function confirmationOf(data) {
  return String((data && data.shopConfirmation) || "").trim().toLowerCase();
}

function isAccepted(data) {
  return ACCEPTED_STATUSES.includes(String((data && data.status) || "").toLowerCase());
}

/**
 * Whether this quotation update is the deal: the builder just accepted it
 * (whole or in part) and the post names it as the selection. The shop does
 * not have to confirm; only a shop that has already backed out gets none.
 */
function shouldIssueInvoice({ before, after, post, quotationId }) {
  if (!after || !post) return false;
  if (!isAccepted(after) || isAccepted(before)) return false;
  if (confirmationOf(after) === "declined") return false;
  return String(post.selectedQuotationId || "") === String(quotationId);
}

/** One invoice per quotation, so a retried trigger cannot post it twice. */
function invoiceMessageId(quotationId) {
  return `invoice_${quotationId}`;
}

function peso(value) {
  return "₱" + value.toLocaleString("en-PH", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function text(value) {
  return String(value ?? "").trim();
}

/**
 * The invoice message, without timestamps (the caller adds those).
 *
 * `quotationSnapshot` carries every line, dropped ones included, because the
 * card already skips lines with `accepted: false` and unavailable ones.
 */
function buildInvoiceMessage({ postId, quotationId, quotation, post, conversation }) {
  const conv = conversation || {};
  const acceptedTotal = invoiceTotal(quotation);
  const shopName = text(conv.shopName) || text(quotation.shopName) || text(post.selectedShopName);
  const builderName = text(conv.builderName) || text(post.ownerName);
  const projectTitle = text(conv.projectTitle) || text(post.projectName);

  return {
    type: "quotation_invoice",
    quotationId: String(quotationId),
    projectId: String(postId),
    acceptedTotal,
    quotationSnapshot: {
      quotationId: String(quotationId),
      projectId: String(postId),
      projectTitle,
      shopName,
      builderName,
      acceptedTotal,
      items: quotationItems(quotation),
    },
    text:
      `[OFFICIAL_TRANSACTION_INVOICE] Quotation Ref #${quotationId} for ` +
      `${peso(acceptedTotal)} confirmed and secured.`,
    senderRole: "system",
    senderId: "system",
  };
}

/** What the chat list shows for the thread after the invoice lands. */
function invoicePreview(acceptedTotal) {
  return `Official quotation issued: ${peso(acceptedTotal)}`;
}

module.exports = {
  shouldIssueInvoice,
  buildInvoiceMessage,
  invoiceMessageId,
  invoicePreview,
  invoiceTotal,
  keptLines,
};
