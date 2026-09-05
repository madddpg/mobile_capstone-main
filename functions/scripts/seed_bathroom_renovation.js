"use strict";

/**
 * Seed Firestore with a starter dataset for:
 *   Project: Bathroom Renovation (slug: bathroom)
 *   Categories: Floor Surface, Floor Installation, Wall Surface, Wall Finishing
 *   Materials: 3–5 per category with is_recommended split
 *
 * Usage (Application Default Credentials):
 *   set GOOGLE_APPLICATION_CREDENTIALS=path\\to\\serviceAccount.json
 *   node functions/scripts/seed_bathroom_renovation.js --project <firebase-project-id>
 *
 * You can also omit --project if your ADC already knows the project.
 */

const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = { projectId: null, dryRun: false };

  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--project") args.projectId = argv[i + 1] || null;
    if (a === "--dry-run") args.dryRun = true;
  }

  return args;
}

function normalizeKey(value) {
  return String(value || "").trim().toLowerCase();
}

async function main() {
  const { projectId, dryRun } = parseArgs(process.argv.slice(2));

  admin.initializeApp(projectId ? { projectId } : undefined);
  const db = admin.firestore();

  const project = {
    name: "Bathroom Renovation",
    slug: "bathroom",
    name_lower: normalizeKey("Bathroom Renovation"),
  };

  const categories = [
    {
      name: "Floor Surface",
      type: "floor",
      order: 1,
      materials: [
        {
          name: "Ceramic Tiles",
          description: "Affordable, easy to maintain, and widely available.",
          is_recommended: true,
        },
        {
          name: "Porcelain Tiles",
          description: "Dense and low-porosity; great for wet areas.",
          is_recommended: true,
        },
        {
          name: "Non-Slip Tiles",
          description: "Textured finish that improves grip in wet zones.",
          is_recommended: true,
        },
        {
          name: "Vinyl Flooring",
          description: "Budget-friendly and water-resistant options exist.",
          is_recommended: false,
        },
        {
          name: "Natural Stone Tiles",
          description: "Premium look; usually needs sealing and maintenance.",
          is_recommended: false,
        },
      ],
    },
    {
      name: "Floor Installation",
      type: "floor",
      order: 2,
      materials: [
        {
          name: "Tile Adhesive",
          description: "Bonding layer that fixes tiles to the substrate.",
          is_recommended: true,
        },
        {
          name: "Grout",
          description: "Fills joints and locks tiles in place; choose mold-resistant.",
          is_recommended: true,
        },
        {
          name: "Tile Spacers",
          description: "Keeps tile gaps consistent for a clean finish.",
          is_recommended: false,
        },
        {
          name: "Self-Leveling Compound",
          description: "Helps create a flat surface before tiling.",
          is_recommended: false,
        },
      ],
    },
    {
      name: "Wall Surface",
      type: "wall",
      order: 3,
      materials: [
        {
          name: "Ceramic Wall Tiles",
          description: "Classic wall finish with wide style options.",
          is_recommended: true,
        },
        {
          name: "PVC Wall Panels",
          description: "Quick install, water-resistant, and easy to clean.",
          is_recommended: false,
        },
        {
          name: "Marble Tiles",
          description: "Luxury look; requires proper sealing in wet areas.",
          is_recommended: false,
        },
        {
          name: "Porcelain Wall Tiles",
          description: "Durable and low-absorption surface.",
          is_recommended: true,
        },
      ],
    },
    {
      name: "Wall Finishing",
      type: "wall",
      order: 4,
      materials: [
        {
          name: "Sealant",
          description: "Seals edges and joints to prevent water ingress.",
          is_recommended: true,
        },
        {
          name: "Tile Trim",
          description: "Finishing profile for corners and exposed edges.",
          is_recommended: false,
        },
        {
          name: "Waterproofing Coating",
          description: "Moisture barrier applied before tile work.",
          is_recommended: true,
        },
        {
          name: "Silicone Caulk",
          description: "Flexible joint seal for corners/changes in plane.",
          is_recommended: false,
        },
      ],
    },
  ];

  const batchWrites = [];

  const projectsRef = db.collection("projects");
  const existingProjectSnap = await projectsRef
    .where("slug", "==", project.slug)
    .limit(1)
    .get();

  const projectRef = existingProjectSnap.empty
    ? projectsRef.doc()
    : existingProjectSnap.docs[0].ref;

  batchWrites.push({
    ref: projectRef,
    data: project,
    merge: true,
  });

  const categoriesRef = db.collection("categories");
  const materialsRef = db.collection("materials");

  // Build writes.
  for (const c of categories) {
    const categoryKey = normalizeKey(c.name);

    const existingCategorySnap = await categoriesRef
      .where("project_id", "==", projectRef.id)
      .where("name_lower", "==", categoryKey)
      .limit(1)
      .get();

    const categoryRef = existingCategorySnap.empty
      ? categoriesRef.doc()
      : existingCategorySnap.docs[0].ref;

    batchWrites.push({
      ref: categoryRef,
      data: {
        project_id: projectRef.id,
        name: c.name,
        type: c.type,
        order: c.order,
        name_lower: categoryKey,
      },
      merge: true,
    });

    // Materials
    for (const m of c.materials) {
      const matKey = normalizeKey(m.name);

      const existingMaterialSnap = await materialsRef
        .where("category_id", "==", categoryRef.id)
        .where("name_lower", "==", matKey)
        .limit(1)
        .get();

      const materialRef = existingMaterialSnap.empty
        ? materialsRef.doc()
        : existingMaterialSnap.docs[0].ref;

      batchWrites.push({
        ref: materialRef,
        data: {
          category_id: categoryRef.id,
          name: m.name,
          name_lower: matKey,
          description: m.description,
          is_recommended: Boolean(m.is_recommended),
        },
        merge: true,
      });
    }
  }

  if (dryRun) {
    console.log(`DRY RUN: would write ${batchWrites.length} documents.`);
    return;
  }

  // Commit in chunks (Firestore batch limit is 500 ops).
  const CHUNK = 400;
  for (let i = 0; i < batchWrites.length; i += CHUNK) {
    const chunk = batchWrites.slice(i, i + CHUNK);
    const batch = db.batch();

    for (const w of chunk) {
      batch.set(w.ref, w.data, { merge: w.merge });
    }

    await batch.commit();
    console.log(`Committed batch ${Math.floor(i / CHUNK) + 1}`);
  }

  console.log("Seed complete.");
  console.log(`Project doc id: ${projectRef.id}`);
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
