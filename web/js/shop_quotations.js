import { getFirestore, doc, runTransaction, serverTimestamp } from "firebase/firestore";
// import { db } from "./firebase-config"; // Import your initialized firestore instance here

/**
 * Submit or Update a Quotation by the hardware shop.
 *
 * The shop only writes its own quotation document. quotationCount and the post
 * status are maintained server-side by the onQuotationSubmitted Cloud Function,
 * because security rules (correctly) forbid a shop from writing to a builder's
 * post.
 *
 * @param {Object} db - The initialized firestore database instance
 * @param {string} postId - The ID of the post the shop is bidding on
 * @param {Object} shopParams - Form data and shop details
 */
function normalizeLineItems(raw) {
  if (!Array.isArray(raw)) return [];

  return raw
    .map((item) => {
      if (typeof item === "string") {
        const name = item.trim();
        return name ? { name } : null;
      }
      if (!item || typeof item !== "object") return null;

      const name = String(
        item.name ||
          item.productName ||
          item.materialName ||
          item.itemName ||
          item.product ||
          item.material ||
          ""
      ).trim();
      if (!name) return null;

      const quantity = Number(item.quantity ?? item.qty ?? 0);
      const unitPrice = Number(item.unitPrice ?? item.price ?? item.unit_price ?? 0);
      const rawSubtotal = item.subtotal ?? item.amount ?? item.lineTotal;
      const computed = Number.isFinite(unitPrice) && Number.isFinite(quantity)
        ? unitPrice * quantity
        : 0;
      const subtotal = Number(rawSubtotal ?? computed);

      return {
        name,
        quantity: Number.isFinite(quantity) ? quantity : 0,
        unit: String(item.unit || ""),
        size: item.size ?? null,
        unitPrice: Number.isFinite(unitPrice) ? unitPrice : 0,
        subtotal: Number.isFinite(subtotal) ? subtotal : 0,
      };
    })
    .filter(Boolean);
}

export async function submitQuotation(db, postId, shopParams) {
  const {
    shopId,
    shopName,
    ownerName,
    userId,
    message,
    estimatedTotal,
    deliveryFee,
    estimatedLeadTime,
    availableMaterials,
    materials,
    lineItems,
  } = shopParams;

  const pricedLines = normalizeLineItems(materials || lineItems || availableMaterials);
  const materialNames = pricedLines.map((line) => line.name);
  const lineTotal = pricedLines.reduce((sum, line) => sum + Number(line.subtotal || 0), 0);
  const quoteTotal = Number(estimatedTotal) || lineTotal;

  const projectPostRef = doc(db, "projectPosts", postId);
  const quotationRef = doc(db, "projectPosts", postId, "quotations", shopId); // Upsert ID pattern (1 per shop)

  try {
    await runTransaction(db, async (transaction) => {
      const postDoc = await transaction.get(projectPostRef);
      if (!postDoc.exists()) throw new Error("Project does not exist!");

      const postData = postDoc.data();
      const postStatus = postData.status;
      if (postStatus === "closed" || postStatus === "awarded" || postStatus === "cancelled") {
        throw new Error("You can no longer submit quotations to this project.");
      }

      const quotationDoc = await transaction.get(quotationRef);
      const isNewQuotation = !quotationDoc.exists();

      // Always notify the builder who owns the post (not the shop account).
      const builderUserId = postData.userId || userId;

      // Setup the Quotation Document
      const quotationData = {
        shopId,
        shopName,
        ownerName,
        postId,
        userId: builderUserId,
        message,
        estimatedTotal: quoteTotal,
        deliveryFee: Number(deliveryFee),
        estimatedLeadTime,
        materials: pricedLines,
        availableMaterials: materialNames,
        status: "submitted",
        updatedAt: serverTimestamp(),
      };

      if (isNewQuotation) {
        quotationData.submittedAt = serverTimestamp();
      }

      transaction.set(quotationRef, quotationData, { merge: true });
    });

    console.log("Quotation successfully submitted!");
    return { success: true, message: "Quotation successfully submitted!" };
  } catch (error) {
    console.error("Quotation submission failed:", error);
    return { success: false, error: error.message };
  }
}
