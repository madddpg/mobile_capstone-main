const express = require("express");
const admin = require("../firebaseAdmin");
const { resolveProjectIdByQuery, resolveCategoryDoc } = require("../utils/database");

const router = express.Router();
const db = admin.firestore();

// GET /materials?category=Floor%20Surface
// or  /materials?categoryId=<docId>
// Optional: &project=bathroom
router.get("/", async (req, res) => {
  try {
    const categoryId = req.query.categoryId;
    const categoryName = req.query.category;

    if (!categoryId && !categoryName) {
      return res.status(400).json({
        error: "Missing required query param: categoryId or category",
      });
    }

    let projectId = null;
    if (req.query.project) {
      projectId = await resolveProjectIdByQuery(req.query.project);
    }

    const categoryDoc = await resolveCategoryDoc(
      categoryId,
      categoryName,
      projectId
    );

    if (!categoryDoc) {
      return res.status(404).json({ error: "Category not found" });
    }

    const categoryData = categoryDoc.data() || {};
    const resolvedCategoryName = String(categoryData.name || "");

    const materialsSnap = await db
      .collection("materials")
      .where("category_id", "==", categoryDoc.id)
      .get();

    const all = materialsSnap.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        id: doc.id,
        name: String(data.name || ""),
        description: String(data.description || ""),
        category: resolvedCategoryName,
        is_recommended: Boolean(data.is_recommended),
        image_url: data.image_url ? String(data.image_url) : null,
      };
    });

    const recommended = all.filter((m) => m.is_recommended).slice(0, 3);
    const alternatives = all.filter((m) => !m.is_recommended);

    return res.status(200).json({
      category: resolvedCategoryName,
      category_id: categoryDoc.id,
      recommended,
      alternatives,
    });
  } catch (error) {
    console.error("GET /materials error:", error);
    return res.status(500).json({ error: "Internal error" });
  }
});

module.exports = router;
