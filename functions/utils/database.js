const admin = require("../firebaseAdmin");
const db = admin.firestore();

function normalizeKey(value) {
  return String(value || "").trim().toLowerCase();
}

async function resolveProjectIdByQuery(projectQuery) {
  const key = normalizeKey(projectQuery);
  if (!key) return null;

  const bySlug = await db
    .collection("projects")
    .where("slug", "==", key)
    .limit(1)
    .get();

  if (!bySlug.empty) {
    return bySlug.docs[0].id;
  }

  const byNameLower = await db
    .collection("projects")
    .where("name_lower", "==", key)
    .limit(1)
    .get();

  if (!byNameLower.empty) {
    return byNameLower.docs[0].id;
  }

  return null;
}

async function resolveCategoryDoc(categoryId, categoryName, projectId) {
  const id = String(categoryId || "").trim();
  if (id) {
    const doc = await db.collection("categories").doc(id).get();
    if (doc.exists) return doc;
  }

  const nameKey = normalizeKey(categoryName);
  if (!nameKey) return null;

  let query = db.collection("categories").where("name_lower", "==", nameKey);
  if (projectId) query = query.where("project_id", "==", projectId);

  const snap = await query.limit(1).get();
  if (snap.empty) return null;
  return snap.docs[0];
}

module.exports = {
  normalizeKey,
  resolveProjectIdByQuery,
  resolveCategoryDoc,
};
