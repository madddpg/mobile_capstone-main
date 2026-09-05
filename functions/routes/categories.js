const express = require("express");
const admin = require("../firebaseAdmin");
const { resolveProjectIdByQuery } = require("../utils/database");

const router = express.Router();
const db = admin.firestore();

// GET /categories?project=bathroom
router.get("/", async (req, res) => {
  try {
    const projectQuery = req.query.project;
    if (!projectQuery) {
      return res
        .status(400)
        .json({ error: "Missing required query param: project" });
    }

    const projectId = await resolveProjectIdByQuery(projectQuery);
    if (!projectId) {
      return res.status(404).json({ error: "Project not found" });
    }

    const categoriesSnap = await db
      .collection("categories")
      .where("project_id", "==", projectId)
      .get();

    const categories = categoriesSnap.docs
      .map((doc) => {
        const data = doc.data() || {};
        return {
          id: doc.id,
          name: String(data.name || ""),
          type: data.type ? String(data.type) : null,
          order: Number.isFinite(Number(data.order)) ? Number(data.order) : 0,
        };
      })
      .sort((a, b) => {
        if (a.order !== b.order) return a.order - b.order;
        return a.name.localeCompare(b.name);
      })
      .map(({ order, ...rest }) => rest);

    return res.status(200).json({ project_id: projectId, categories });
  } catch (error) {
    console.error("GET /categories error:", error);
    return res.status(500).json({ error: "Internal error" });
  }
});

module.exports = router;
