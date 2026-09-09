"use strict";

/**
 * Push notifications for chat messages.
 *
 * A Cloud Function deployed from the shop dashboard used to do this. It was
 * removed when the builder repository deployed over the shared project, and
 * chat is a builder-side feature, so it lives here now. Only one of the two
 * repositories may own this: if both deploy a message trigger, every message
 * sends two pushes.
 *
 * Split out of index.js so the recipient logic can be unit tested without a
 * Firestore connection, since picking the wrong participant would push a
 * builder's own message back at them.
 */

/**
 * Works out who should be told about a message.
 *
 * Conversations store the builder under `builderId`, `userId`, or both,
 * depending on which client created the thread, so all the spellings are
 * checked. Returns null when there is nobody to notify: a system message, a
 * sender who is not a participant, or a thread missing one side.
 */
function recipientFor(conversation, message) {
  if (!conversation || !message) return null;

  const role = String(message.senderRole || "").toLowerCase();
  if (role === "system") return null;

  const senderId = String(message.senderId || "").trim();
  if (!senderId) return null;

  const shopId = String(conversation.shopId || "").trim();
  const builderId = String(
    conversation.builderId || conversation.userId || ""
  ).trim();

  if (!shopId || !builderId) return null;

  // Notify whichever side did not write it. A sender who matches neither
  // participant is not part of this thread, so nothing is sent.
  if (senderId === builderId) return { uid: shopId, audience: "shop" };
  if (senderId === shopId) return { uid: builderId, audience: "builder" };
  return null;
}

/**
 * One line describing the message for the notification body.
 *
 * An attachment with no caption would otherwise arrive as an empty push, which
 * tells the reader nothing and looks broken.
 */
function previewFor(message, { maxLength = 120 } = {}) {
  const text = String((message && message.text) || "").trim();
  if (text) {
    return text.length > maxLength ? `${text.slice(0, maxLength - 1)}…` : text;
  }

  const attachment = message && message.attachment;
  if (attachment && attachment.url) {
    return attachment.kind === "image" ? "Sent a photo" : "Sent an attachment";
  }
  return "Sent a message";
}

/** Who the notification says it is from, as the recipient would recognise them. */
function senderLabelFor(conversation, audience) {
  if (audience === "builder") {
    return String(conversation.shopName || "").trim() || "A hardware shop";
  }
  return String(conversation.builderName || "").trim() || "A builder";
}

module.exports = { recipientFor, previewFor, senderLabelFor };
